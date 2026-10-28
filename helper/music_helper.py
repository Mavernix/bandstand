# helper process for the music app: searches youtube music and resolves stream urls.
# speaks json lines on stdin/stdout, one request per line, one response per line.
#
# request:  {"id": 1, "command": "search", "query": "aurora vale", "kind": "albums"}
# response: {"id": 1, "ok": true, ...}  or  {"id": 1, "ok": false, "error": "..."}
#
# commands (args -> response fields, track/card shapes are in youtube_music.py):
#   search    query, kind = songs|albums|artists|playlists  -> tracks (songs) or cards
#   album     browse_id  -> title, artist, year, duration_text, thumbnail_url, tracks
#   artist    browse_id  -> name, description, thumbnail_url, songs, albums, singles
#   playlist  browse_id  -> title, author, duration_text, thumbnail_url, tracks
#   home                 -> shelves: [{title, items}], items are tracks or cards
#   radio     video_id   -> tracks, the seed song first
#   stream    video_id   -> url, expires_epoch (0 if unknown), duration_seconds
#
# requests run concurrently (stream lookups take seconds), so responses can come
# back out of order. match them by id.

import json
import sys
import threading
from concurrent.futures import ThreadPoolExecutor

from audio_relay import AudioRelay
from streams import YtDlpStreams
from youtube_music import HelperError, YouTubeMusic

# a search sends four requests at once; leave room so a song lookup never waits behind it
MAX_WORKERS = 8

REQUIRED_ARGS = {
    "search": ("query",),
    "stream": ("video_id",),
    "album": ("browse_id",),
    "artist": ("browse_id",),
    "playlist": ("browse_id",),
    "radio": ("video_id",),
    "home": (),
}


class Helper:
    def __init__(self, music, streams):
        self._music = music
        self._streams = streams

    def handle(self, request):
        """Returns the response dict for one request. Never raises."""
        response = {"id": request.get("id") if isinstance(request, dict) else None}
        try:
            response.update(self._run(request))
            response["ok"] = True
        except HelperError as error:
            response.update({"ok": False, "error": str(error)})
        except Exception as error:  # noqa: BLE001 - a library crash must not kill the helper
            response.update({"ok": False, "error": "unexpected %s: %s" % (type(error).__name__, error)})
        return response

    def _run(self, request):
        if not isinstance(request, dict):
            raise HelperError("request must be a JSON object")

        command = request.get("command")
        if command not in REQUIRED_ARGS:
            raise HelperError("unknown command %r (expected one of: %s)" % (command, ", ".join(REQUIRED_ARGS)))

        for name in REQUIRED_ARGS[command]:
            value = request.get(name)
            if not isinstance(value, str) or not value.strip():
                raise HelperError('%s requires a non-empty "%s"' % (command, name))

        if command == "search":
            return self._music.search(request["query"], request.get("kind", "songs"))
        if command == "stream":
            return self._streams.find_audio(request["video_id"])
        if command == "album":
            return self._music.album(request["browse_id"])
        if command == "artist":
            return self._music.artist(request["browse_id"])
        if command == "playlist":
            return self._music.playlist(request["browse_id"])
        if command == "radio":
            return self._music.radio(request["video_id"])
        return self._music.home()


def serve(lines, output, helper):
    write_lock = threading.Lock()

    def send(response):
        line = json.dumps(response, ensure_ascii=False)
        with write_lock:
            output.write(line + "\n")
            output.flush()

    def respond(request):
        send(helper.handle(request))

    # leaving the with block waits for pending requests, so nothing is lost on eof
    with ThreadPoolExecutor(max_workers=MAX_WORKERS) as pool:
        for line in lines:
            if not line.strip():
                continue
            try:
                request = json.loads(line)
            except json.JSONDecodeError as error:
                send({"id": None, "ok": False, "error": "invalid JSON: %s" % error})
                continue
            pool.submit(respond, request)


def main():
    serve(sys.stdin, sys.stdout, Helper(YouTubeMusic(), YtDlpStreams(AudioRelay())))


if __name__ == "__main__":
    main()
