# resolves a video id to a playable audio url with yt-dlp.
# yt-dlp needs deno to solve youtube's js challenge before it hands out a url.

import urllib.parse

from audio_relay import size_from_url
from youtube_music import HelperError

# without this yt-dlp can hang forever on a dead connection
SOCKET_TIMEOUT_SECONDS = 20

# ffmpeg sniffs the format anyway, this is just a courtesy header
CONTENT_TYPES = {"webm": "audio/webm", "m4a": "audio/mp4"}


def expiry_from_url(url):
    # googlevideo urls carry ?expire=<unix time>
    values = urllib.parse.parse_qs(urllib.parse.urlparse(url).query).get("expire")
    try:
        return int(values[0]) if values else 0
    except ValueError:
        return 0


class YtDlpStreams:
    def __init__(self, relay):
        self._relay = relay

    def find_audio(self, video_id):
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
                info = ydl.extract_info("https://music.youtube.com/watch?v=" + video_id, download=False)
        except yt_dlp.utils.DownloadError as error:
            # yt-dlp's message already says what's wrong (offline, video removed, no js runtime)
            raise HelperError(str(error)) from error

        url = info.get("url")
        if not url:
            raise HelperError("yt-dlp found no audio stream for " + video_id)

        size = info.get("filesize") or size_from_url(url)
        if size:
            content_type = CONTENT_TYPES.get(info.get("ext"), "application/octet-stream")
            play_url = self._relay.add_song(url, size, content_type, info.get("http_headers") or {})
        else:
            # the relay can't serve byte ranges without the size, so play straight from youtube
            play_url = url

        return {
            "url": play_url,
            "expires_epoch": expiry_from_url(url),
            "duration_seconds": info.get("duration") or 0,
        }
