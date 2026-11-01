# keeps songs on disk, so playing one again starts at once and doesn't need youtube.
# each song is two files in the cache folder:
#   ID.audio   the audio exactly as youtube sent it
#   ID.json    {size, content_type, duration_seconds}
# while it downloads the audio is ID.<random>.audio.part; it's renamed into place once complete.
# when the folder grows past its limit the songs played longest ago go first.
#
# only the song playing and the one coming up are downloaded. when the player moves past
# a song before it's complete (a skip), its download stops, so skipping through a list
# doesn't fetch every song in it.

import collections
import contextlib
import json
import os
import re
import sys
import tempfile
import threading
import time

from audio_relay import CopyFailed, CopyStopped, copy_remote

# youtube video ids are 11 of these; anything else never becomes a file name (see fullmatch)
VIDEO_ID_PATTERN = re.compile(r"[A-Za-z0-9_-]{1,64}")

AUDIO_SUFFIX = ".audio"
INFO_SUFFIX = ".json"
PART_SUFFIX = ".part"

# what a song is to the player; a song that's neither stops downloading (see SongCache.want)
PLAYING = "playing"
COMING_UP = "coming up"

# one for the song playing, one for the song coming up
MAX_DOWNLOADS = 2

# the relay waits for the download when it's at most this far behind the player:
# the download comes in at full speed, so it gets there before a second request would
FOLLOW_BYTES = 2 * 1024 * 1024
# and gives up waiting after this, e.g. while the download retries a broken piece
FOLLOW_TIMEOUT_SECONDS = 5

# a .part file nobody wrote to for this long was left behind by a helper that quit.
# younger ones may belong to another bandstand downloading into the same folder
LEFTOVER_AFTER_SECONDS = 10 * 60


def log(format, *args):
    # stdout is reserved for the json protocol
    sys.stderr.write("song cache: " + (format % args) + "\n")


class CacheWriteFailed(Exception):
    """The disk copy couldn't be written (disk full, folder gone)."""


class CachedSong:
    def __init__(self, video_id, path, size, content_type, duration_seconds):
        self.video_id = video_id
        self.path = path
        self.size = size
        self.content_type = content_type
        self.duration_seconds = duration_seconds


class Download:
    """Fetches one song into a .part file in the background. The relay reads along."""

    def __init__(self, cache, song, duration_seconds):
        self.song = song  # an audio_relay.Song for youtube
        self.duration_seconds = duration_seconds
        self._cache = cache
        # chosen when the download starts. each download has its own, so a cancelled one
        # cleaning up can't remove the file of a new download of the same song
        self._path = None
        # bytes on disk, from the start of the song
        self._on_disk = 0
        self._running = False
        self._cancelled = False
        self._cond = threading.Condition()

    def start(self):
        threading.Thread(target=self._run, daemon=True).start()

    def wait_for(self, position):
        """Returns how many bytes are on disk, after waiting a moment if position is close ahead."""
        with self._cond:
            self._cond.wait_for(
                lambda: self._on_disk > position or not self._running or position - self._on_disk >= FOLLOW_BYTES,
                timeout=FOLLOW_TIMEOUT_SECONDS,
            )
            return self._on_disk

    def open(self):
        """The file being downloaded into, to read from, or None if the download failed and
        took its file along. An open file stays readable after it's renamed or removed."""
        # under the lock, so the file can't be renamed or removed between the check and the open
        with self._cond:
            return open(self._path, "rb") if self._on_disk > 0 else None

    def cancel(self):
        with self._cond:
            self._cancelled = True

    @property
    def cancelled(self):
        with self._cond:
            return self._cancelled

    def fetches_same_file(self, song):
        # every lookup gives a new url; the same size and type mean the same file behind it
        return self.song.size == song.size and self.song.content_type == song.content_type

    def _run(self):
        try:
            with self._cache.download_slots:
                # it may have waited for a slot long enough to be skipped
                if self.cancelled:
                    return
                os.makedirs(self._cache.directory, exist_ok=True)
                handle, path = tempfile.mkstemp(
                    prefix=self.song.video_id + ".", suffix=AUDIO_SUFFIX + PART_SUFFIX, dir=self._cache.directory)
                with open(handle, "wb") as file:
                    with self._cond:
                        self._path = path
                        self._running = True
                    copy_remote(self.song, 0, self.song.size - 1, lambda block: self._write(file, block),
                                stopped=lambda: self.cancelled)
                self._finish()
        except CopyStopped:
            # the player moved past the song before it was complete
            self._discard()
        except (CopyFailed, CacheWriteFailed, OSError) as error:
            log("couldn't keep %s: %s", self.song.video_id, error)
            self._discard()
        finally:
            with self._cond:
                self._running = False
                self._cond.notify_all()
            self._cache.download_ended(self)

    def _discard(self):
        with self._cond:
            self._on_disk = 0
        if self._path is not None:
            with contextlib.suppress(OSError):
                os.remove(self._path)

    def _write(self, file, block):
        try:
            file.write(block)
            # readers have their own file, they only see what's flushed
            file.flush()
        except OSError as error:
            # not an OSError any more, or copy_remote would take it for youtube failing and retry
            raise CacheWriteFailed(str(error)) from error
        with self._cond:
            self._on_disk += len(block)
            self._cond.notify_all()

    def _finish(self):
        video_id = self.song.video_id
        info = {"size": self.song.size, "content_type": self.song.content_type,
                "duration_seconds": self.duration_seconds}
        _write_atomically(self._cache.path(video_id, INFO_SUFFIX), json.dumps(info).encode())
        audio_path = self._cache.path(video_id, AUDIO_SUFFIX)
        with self._cond:
            os.replace(self._path, audio_path)
            self._path = audio_path


class SongCache:
    def __init__(self, directory, limit_bytes):
        self.directory = directory
        self.limit_bytes = limit_bytes
        self.download_slots = threading.BoundedSemaphore(MAX_DOWNLOADS)
        self._lock = threading.Lock()
        self._downloads = {}
        # video ids the relay hands out, these are never evicted
        self._held = collections.Counter()
        # PLAYING and COMING_UP -> video id
        self._wanted = {}

    def path(self, video_id, suffix):
        return os.path.join(self.directory, video_id + suffix)

    def cached(self, video_id):
        """The complete song on disk as a CachedSong, or None. Counts as a use for eviction."""
        if not VIDEO_ID_PATTERN.fullmatch(video_id):
            return None
        audio_path = self.path(video_id, AUDIO_SUFFIX)
        try:
            with open(self.path(video_id, INFO_SUFFIX), "rb") as file:
                info = json.load(file)
            size = os.path.getsize(audio_path)
            if size != info["size"]:
                return None
            os.utime(audio_path)
            return CachedSong(video_id, audio_path, size, info["content_type"], info.get("duration_seconds", 0))
        except (OSError, ValueError, KeyError, TypeError):
            return None

    def want(self, role, video_id):
        """Tells which song is PLAYING or COMING_UP. The song that had the role before stops
        downloading, unless it still has the other one (the song coming up started playing)."""
        with self._lock:
            before = self._wanted.get(role)
            # one role per song: the song coming up that starts playing isn't coming up any more,
            # so skipping on past it before the next prepare still stops its download
            self._wanted = {other: wanted for other, wanted in self._wanted.items() if wanted != video_id}
            self._wanted[role] = video_id
            skipped = self._downloads.get(before)
            if skipped is not None and before not in self._wanted.values():
                skipped.cancel()

    def download(self, song, duration_seconds):
        """Starts keeping the song (an audio_relay.Song with its video_id), returns its Download.
        Returns the running one if it's downloading already, None if it can't be kept or the
        song isn't PLAYING or COMING_UP any more (it was skipped while it was looked up)."""
        if not VIDEO_ID_PATTERN.fullmatch(song.video_id) or song.size > self.limit_bytes:
            return None
        with self._lock:
            if song.video_id not in self._wanted.values():
                return None

            running = self._downloads.get(song.video_id)
            # a cancelled one is on its way out (the user went back to a song they skipped),
            # and one of another file came from an older lookup that youtube answered differently
            if running is not None and not running.cancelled and running.fetches_same_file(song):
                return running
            if running is not None:
                running.cancel()

            download = Download(self, song, duration_seconds)
            self._downloads[song.video_id] = download
            download.start()
            return download

    def download_ended(self, download):
        with self._lock:
            if self._downloads.get(download.song.video_id) is download:
                del self._downloads[download.song.video_id]
        self.evict()

    def hold(self, video_id):
        """Keeps the song from being evicted until release() is called as often."""
        with self._lock:
            self._held[video_id] += 1

    def release(self, video_id):
        with self._lock:
            self._held[video_id] -= 1
            if self._held[video_id] <= 0:
                del self._held[video_id]

    def evict(self):
        """Removes the songs played longest ago until the folder fits, and leftovers of a crash."""
        with self._lock:
            busy = set(self._downloads) | set(self._held)
            try:
                entries = list(os.scandir(self.directory))
            except OSError:
                return  # nothing kept yet

            songs = []
            infos = set()
            # songs in use count toward the limit, they just aren't removed
            total = 0
            for entry in entries:
                video_id, suffix = _split(entry.name)
                if video_id in busy:
                    if suffix == AUDIO_SUFFIX:
                        with contextlib.suppress(OSError):
                            total += entry.stat().st_size
                    continue
                if suffix == AUDIO_SUFFIX:
                    with contextlib.suppress(OSError):
                        status = entry.stat()
                        songs.append((status.st_mtime, status.st_size, video_id))
                elif suffix == INFO_SUFFIX:
                    infos.add(video_id)
                elif suffix.endswith(PART_SUFFIX):
                    # a download that was cut off when a helper quit
                    with contextlib.suppress(OSError):
                        if time.time() - entry.stat().st_mtime > LEFTOVER_AFTER_SECONDS:
                            os.remove(entry.path)

            for video_id in infos - {video_id for _, _, video_id in songs}:
                with contextlib.suppress(OSError):
                    os.remove(self.path(video_id, INFO_SUFFIX))

            total += sum(size for _, size, _ in songs)
            for _, size, video_id in sorted(songs):
                if total <= self.limit_bytes:
                    break
                for suffix in (AUDIO_SUFFIX, INFO_SUFFIX):
                    with contextlib.suppress(OSError):
                        os.remove(self.path(video_id, suffix))
                total -= size


def _split(name):
    # "abc.x7k2.audio.part" -> ("abc", ".x7k2.audio.part")
    dot = name.find(".")
    return (name, "") if dot < 0 else (name[:dot], name[dot:])


def _write_atomically(path, data):
    part = path + PART_SUFFIX
    with open(part, "wb") as file:
        file.write(data)
    os.replace(part, path)
