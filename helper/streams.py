# resolves a video id to a playable audio url with yt-dlp.
# yt-dlp needs deno to solve youtube's js challenge before it hands out a url.
# lookups are remembered until shortly before youtube's url expires, or until youtube
# stops serving the url. with a song cache a song complete on disk is played from there
# without asking yt-dlp at all.

import threading
import time
import urllib.parse
import urllib.request
from concurrent.futures import Future

from audio_relay import Song, size_from_url
from song_cache import COMING_UP, PLAYING
from youtube_music import HelperError

# without this yt-dlp can hang forever on a dead connection
SOCKET_TIMEOUT_SECONDS = 20

# ffmpeg sniffs the format anyway, this is just a courtesy header
CONTENT_TYPES = {"webm": "audio/webm", "m4a": "audio/mp4"}

# a remembered lookup is used again only if its url still has this long to live,
# enough to play a long song to the end
LOOKUP_MARGIN_SECONDS = 10 * 60

# for asking youtube whether a remembered url still works, see Lookup.still_works()
CHECK_TIMEOUT_SECONDS = 5


def expiry_from_url(url):
    # googlevideo urls carry ?expire=<unix time>
    values = urllib.parse.parse_qs(urllib.parse.urlparse(url).query).get("expire")
    try:
        return int(values[0]) if values else 0
    except ValueError:
        return 0


class Lookup:
    """What yt-dlp found for one song."""

    def __init__(self, url, size, content_type, headers, duration_seconds):
        self.url = url
        self.size = size
        self.content_type = content_type
        self.headers = headers
        self.duration_seconds = duration_seconds
        self.expires_epoch = expiry_from_url(url)

    def still_fresh(self):
        # without a known expiry we can't tell, so it isn't reused
        return self.expires_epoch - time.time() > LOOKUP_MARGIN_SECONDS

    def still_works(self):
        """Asks youtube for the first byte. A url can stop working before it expires (it only
        works from the network it was looked up on), and the player would fail on it first."""
        first_byte = Song(self.url, self.size, self.content_type, self.headers).piece_url(0, 0)
        try:
            request = urllib.request.Request(first_byte, headers=self.headers)
            with urllib.request.urlopen(request, timeout=CHECK_TIMEOUT_SECONDS) as response:
                return len(response.read(1)) == 1
        except OSError:
            return False


class YtDlpStreams:
    def __init__(self, relay, cache=None):
        self._relay = relay
        # a song_cache.SongCache, or None to keep nothing on disk
        self._cache = cache
        # video id -> Lookup
        self._lookups = {}
        # video id -> Future of the Lookup yt-dlp is working on, so a prepare and a play
        # of the same song at once run yt-dlp only once
        self._pending = {}
        self._lock = threading.Lock()

    def find_audio(self, video_id):
        if self._cache is not None:
            self._cache.want(PLAYING, video_id)
            cached = self._cache.cached(video_id)
            if cached is not None:
                return {
                    "url": self._relay.add_file(cached),
                    "expires_epoch": 0,
                    "duration_seconds": cached.duration_seconds,
                }

        lookup = self._look_up(video_id)
        if lookup.size:
            song = self._song(video_id, lookup)
            play_url = self._relay.add_song(song, self._keep(song, lookup))
        else:
            # the relay can't serve byte ranges without the size, so play straight from youtube
            play_url = lookup.url

        return {
            "url": play_url,
            "expires_epoch": lookup.expires_epoch,
            "duration_seconds": lookup.duration_seconds,
        }

    def prepare(self, video_id):
        """Looks the song up and starts keeping it on disk, so playing it later starts at once."""
        if self._cache is not None:
            self._cache.want(COMING_UP, video_id)
            if self._cache.cached(video_id) is not None:
                return {}

        lookup = self._look_up(video_id)
        if lookup.size:
            self._keep(self._song(video_id, lookup), lookup)
        return {}

    def _song(self, video_id, lookup):
        return Song(lookup.url, lookup.size, lookup.content_type, lookup.headers, video_id,
                    on_failure=lambda: self._forget(video_id, lookup))

    def _keep(self, song, lookup):
        """Starts keeping the song on disk, returns its song_cache.Download (None without a cache)."""
        if self._cache is None:
            return None
        return self._cache.download(song, lookup.duration_seconds)

    def _look_up(self, video_id):
        """What yt-dlp finds for the song. Remembered while its url lasts and works."""
        with self._lock:
            remembered = self._lookups.get(video_id)
        if remembered is not None and remembered.still_fresh():
            if remembered.still_works():
                return remembered
            self._forget(video_id, remembered)

        with self._lock:
            pending = self._pending.get(video_id)
            someone_else_asked = pending is not None
            if not someone_else_asked:
                pending = self._pending[video_id] = Future()

        if someone_else_asked:
            return pending.result()  # raises what the other request's lookup raised

        try:
            lookup = self._run_yt_dlp(video_id)
        except Exception as error:
            with self._lock:
                del self._pending[video_id]
            pending.set_exception(error)
            raise

        with self._lock:
            del self._pending[video_id]
            # drop the ones that went stale, so this doesn't grow forever
            self._lookups = {key: value for key, value in self._lookups.items() if value.still_fresh()}
            # a url without a size goes to the player straight from youtube, where we can't
            # see it fail, so only the ones the relay serves (and watches) are remembered
            if lookup.size:
                self._lookups[video_id] = lookup
        pending.set_result(lookup)
        return lookup

    def _forget(self, video_id, lookup):
        # youtube stopped serving the url, e.g. it only works from the network it was looked
        # up on and the computer changed networks. the next play looks the song up again.
        with self._lock:
            if self._lookups.get(video_id) is lookup:
                del self._lookups[video_id]

    def _run_yt_dlp(self, video_id):
        info = self._extract_info(video_id)
        url = info.get("url")
        if not url:
            raise HelperError("yt-dlp found no audio stream for " + video_id)
        return Lookup(
            url,
            info.get("filesize") or size_from_url(url),
            CONTENT_TYPES.get(info.get("ext"), "application/octet-stream"),
            info.get("http_headers") or {},
            info.get("duration") or 0,
        )

    def _extract_info(self, video_id):
        try:
            import yt_dlp  # lazy, so a missing install shows up as an error response
        except ImportError as error:
            raise HelperError("yt-dlp is not installed (on Arch: pacman -S yt-dlp)") from error

        options = {
            "format": "bestaudio/best",
            "quiet": True,
            "no_warnings": True,
            "noplaylist": True,
            "socket_timeout": SOCKET_TIMEOUT_SECONDS,
        }
        try:
            with yt_dlp.YoutubeDL(options) as ydl:
                return ydl.extract_info("https://music.youtube.com/watch?v=" + video_id, download=False)
        except yt_dlp.utils.DownloadError as error:
            # yt-dlp's message already says what's wrong (offline, video removed, no js runtime)
            raise HelperError(str(error)) from error
