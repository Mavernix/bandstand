# local http relay between the player and youtube's audio servers.
# youtube throttles one long download to roughly playback speed and sometimes drops it,
# and ffmpeg doesn't reconnect, so playback died midway with "Demuxing failed -5".
# ranged requests (&range=first-last, same as yt-dlp uses) come back at full speed,
# so we fetch the song in 1 MiB pieces and resume a broken piece where it stopped.

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
    def __init__(self, remote_url, size, content_type, headers):
        self.remote_url = remote_url
        self.size = size
        self.content_type = content_type
        self.headers = headers

    def piece_url(self, first, last):
        separator = "&" if "?" in self.remote_url else "?"
        return "%s%srange=%d-%d" % (self.remote_url, separator, first, last)


class ClientDisconnected(Exception):
    """The player closed the connection (seek, skip or stop). Not an error."""


class AudioRelay:
    def __init__(self):
        self._songs = {}
        self._lock = threading.Lock()
        self._server = None

    def add_song(self, remote_url, size, content_type, headers):
        """Registers a song and returns the local url the player should use."""
        token = secrets.token_urlsafe(16)
        with self._lock:
            self._songs[token] = Song(remote_url, size, content_type, headers)
            # dicts keep insertion order, so this drops the oldest
            while len(self._songs) > MAX_SONGS:
                del self._songs[next(iter(self._songs))]
            port = self._ensure_server()
        return "http://127.0.0.1:%d/audio/%s" % (port, token)

    def song(self, token):
        with self._lock:
            return self._songs.get(token)

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

    def _copy_range(self, song, first, last):
        position = first
        stalled = 0
        while position <= last:
            piece_start = position
            piece_end = min(position + PIECE_BYTES - 1, last)
            try:
                request = urllib.request.Request(song.piece_url(position, piece_end), headers=song.headers)
                with urllib.request.urlopen(request, timeout=SOCKET_TIMEOUT_SECONDS) as response:
                    while position <= piece_end:
                        block = response.read(min(COPY_BLOCK_BYTES, piece_end - position + 1))
                        if not block:
                            raise OSError("server ended the piece early at byte %d of %d" % (position, piece_end))
                        self._send(block)
                        position += len(block)
                stalled = 0
            except OSError as error:  # includes urllib's URLError and HTTPError
                stalled = 0 if position > piece_start else stalled + 1
                if stalled >= MAX_STALLED_ATTEMPTS:
                    # closing short of content-length makes the player report the failure
                    self.log_error("gave up at byte %d: %s", position, error)
                    return
                time.sleep(RETRY_DELAY_SECONDS)

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
