# local http relay between the player and youtube's audio servers.
# youtube throttles one long download to roughly playback speed and sometimes drops it,
# and ffmpeg doesn't reconnect, so playback died midway with "Demuxing failed -5".
# ranged requests (&range=first-last, same as yt-dlp uses) come back at full speed,
# so we fetch the song in 1 MiB pieces and resume a broken piece where it stopped.
# with a song cache (song_cache.py) a song is also downloaded to disk in the background;
# what is on disk already is served from there, and a song complete on disk never asks youtube.

import http.server
import re
import secrets
import threading
import time
import urllib.parse
import urllib.request

# small enough that no single connection lives long enough to get throttled
PIECE_BYTES = 1024 * 1024
COPY_BLOCK_BYTES = 64 * 1024

# give up after this many failed attempts in a row that made no progress
MAX_STALLED_ATTEMPTS = 4
RETRY_DELAY_SECONDS = 1
SOCKET_TIMEOUT_SECONDS = 20

# the player only reads one song at a time, a few extra cover fast skipping
MAX_SONGS = 8

# ffmpeg only ever sends a single "bytes=first-" or "bytes=first-last"
RANGE_PATTERN = re.compile(r"^bytes=(\d+)-(\d*)$")


class Song:
    def __init__(self, remote_url, size, content_type, headers, video_id="", on_failure=None):
        self.remote_url = remote_url
        self.size = size
        self.content_type = content_type
        self.headers = headers
        self.video_id = video_id
        # called when youtube stopped serving remote_url, so it isn't handed out again
        self.on_failure = on_failure
        # a song_cache.Download filling the disk copy, served from where it has got to
        self.download = None
        # a complete copy on disk; remote_url is unused then
        self.path = None

    def piece_url(self, first, last):
        separator = "&" if "?" in self.remote_url else "?"
        return "%s%srange=%d-%d" % (self.remote_url, separator, first, last)


class ClientDisconnected(Exception):
    """The player closed the connection (seek, skip or stop). Not an error."""


class CopyFailed(Exception):
    """Youtube kept failing, or a file on disk ended early. The message says where."""


class CopyStopped(Exception):
    """Whoever asked for the copy doesn't want it any more."""


def copy_remote(song, first, last, write, stopped=lambda: False):
    """Hands bytes first..last of the song from youtube to write(block), piece by piece.
    Returns last + 1. Raises CopyFailed when youtube stops making progress, and CopyStopped
    once stopped() is true; it's asked after every block and before every attempt, so a
    copy stuck retrying a broken connection stops too."""
    position = first
    stalled = 0
    while position <= last:
        if stopped():
            raise CopyStopped()
        piece_start = position
        piece_end = min(position + PIECE_BYTES - 1, last)
        try:
            request = urllib.request.Request(song.piece_url(position, piece_end), headers=song.headers)
            with urllib.request.urlopen(request, timeout=SOCKET_TIMEOUT_SECONDS) as response:
                while position <= piece_end:
                    block = response.read(min(COPY_BLOCK_BYTES, piece_end - position + 1))
                    if not block:
                        raise OSError("server ended the piece early at byte %d of %d" % (position, piece_end))
                    write(block)
                    position += len(block)
                    if stopped():
                        raise CopyStopped()
            stalled = 0
        except OSError as error:  # includes urllib's URLError and HTTPError
            stalled = 0 if position > piece_start else stalled + 1
            if stalled >= MAX_STALLED_ATTEMPTS:
                if song.on_failure is not None:
                    song.on_failure()
                raise CopyFailed("gave up at byte %d: %s" % (position, error)) from error
            time.sleep(RETRY_DELAY_SECONDS)
    return position


class AudioRelay:
    def __init__(self, cache=None):
        self._songs = {}
        self._lock = threading.Lock()
        self._server = None
        # a song_cache.SongCache, so songs the player may still ask for aren't evicted
        self._cache = cache

    def add_song(self, song, download=None):
        """Registers a song from youtube and returns the local url the player should use.
        download is the song_cache.Download filling its disk copy, if there is one."""
        song.download = download
        return self._add(song)

    def add_file(self, cached):
        """Registers a song complete on disk (a song_cache.CachedSong), returns its local url."""
        song = Song(None, cached.size, cached.content_type, {}, cached.video_id)
        song.path = cached.path
        return self._add(song)

    def _add(self, song):
        token = secrets.token_urlsafe(16)
        with self._lock:
            self._songs[token] = song
            self._hold(song)
            # dicts keep insertion order, so this drops the oldest
            while len(self._songs) > MAX_SONGS:
                self._release(self._songs.pop(next(iter(self._songs))))
            port = self._ensure_server()
        return "http://127.0.0.1:%d/audio/%s" % (port, token)

    def song(self, token):
        with self._lock:
            return self._songs.get(token)

    # the player can come back for a song at any time (a seek), so its file stays
    # in the cache for as long as its url works
    def _hold(self, song):
        if self._cache is not None and song.video_id:
            self._cache.hold(song.video_id)

    def _release(self, song):
        if self._cache is not None and song.video_id:
            self._cache.release(song.video_id)

    def _ensure_server(self):
        if self._server is None:
            class Handler(RelayHandler):
                relay = self

            self._server = http.server.ThreadingHTTPServer(("127.0.0.1", 0), Handler)
            self._server.daemon_threads = True
            threading.Thread(target=self._server.serve_forever, daemon=True).start()
        return self._server.server_address[1]


class RelayHandler(http.server.BaseHTTPRequestHandler):
    relay = None  # set per server by AudioRelay

    def do_GET(self):
        song = self.relay.song(self.path.removeprefix("/audio/"))
        if song is None:
            self.send_error(404, "unknown or expired song url")
            return

        first, last = 0, song.size - 1
        range_header = self.headers.get("Range")
        if range_header:
            match = RANGE_PATTERN.match(range_header.strip())
            if not match or int(match.group(1)) > song.size - 1:
                self.send_response(416)
                self.send_header("Content-Range", "bytes */%d" % song.size)
                self.end_headers()
                return
            first = int(match.group(1))
            if match.group(2):
                last = min(int(match.group(2)), song.size - 1)

        self.send_response(206 if range_header else 200)
        self.send_header("Content-Type", song.content_type)
        self.send_header("Accept-Ranges", "bytes")
        self.send_header("Content-Length", str(last - first + 1))
        if range_header:
            self.send_header("Content-Range", "bytes %d-%d/%d" % (first, last, song.size))
        self.end_headers()

        try:
            self._copy_range(song, first, last)
        except ClientDisconnected:
            pass
        except (CopyFailed, OSError) as error:
            # closing short of content-length makes the player report the failure
            self.log_error("%s", error)

    def _copy_range(self, song, first, last):
        if song.path is not None:
            with open(song.path, "rb") as file:
                self._copy_file(file, first, last)
            return

        position = first
        file = None
        try:
            while position <= last:
                # waits a moment if the download is about to get there
                on_disk = song.download.wait_for(position) if song.download is not None else 0
                if on_disk > position and file is None:
                    file = song.download.open()
                if on_disk > position and file is not None:
                    end = min(on_disk - 1, last)
                    self._copy_file(file, position, end)
                    position = end + 1
                else:
                    # not on disk yet, or the download failed just now and took its file along.
                    # one piece at a time, so we switch to the disk copy as soon as it catches up
                    position = copy_remote(song, position, min(position + PIECE_BYTES - 1, last), self._send)
        finally:
            if file is not None:
                file.close()

    def _copy_file(self, file, first, last):
        file.seek(first)
        position = first
        while position <= last:
            block = file.read(min(COPY_BLOCK_BYTES, last - position + 1))
            if not block:
                raise CopyFailed("the file on disk ended early at byte %d of %d" % (position, last))
            self._send(block)
            position += len(block)

    def _send(self, block):
        try:
            self.wfile.write(block)
        except (BrokenPipeError, ConnectionResetError) as error:
            raise ClientDisconnected() from error

    def log_message(self, format, *args):
        pass  # don't log every request

    def log_error(self, format, *args):
        # the base log_message writes to stderr, stdout is reserved for the json protocol
        http.server.BaseHTTPRequestHandler.log_message(self, "audio relay: " + format, *args)


def size_from_url(url):
    # googlevideo urls carry the file size as &clen=<bytes>
    values = urllib.parse.parse_qs(urllib.parse.urlparse(url).query).get("clen")
    if not values or not values[0].isdigit():
        return 0
    return int(values[0])
