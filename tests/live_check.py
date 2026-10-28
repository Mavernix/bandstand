# end-to-end check of the helper against the real youtube music, one call per command.
# needs network, python-ytmusicapi, yt-dlp and deno, so it's not part of the unit tests:
#   python3 -I tests/live_check.py ["search query"]

import json
import pathlib
import subprocess
import sys
import time
import urllib.request

HELPER = pathlib.Path(__file__).resolve().parent.parent / "helper" / "music_helper.py"
DEFAULT_QUERY = "Bach cello suite 1 prelude"

# stream lookups include solving youtube's js challenge with deno, which can take a while
TIMEOUT_SECONDS = 90


class HelperProcess:
    def __init__(self):
        self._process = subprocess.Popen(
            [sys.executable, str(HELPER)],
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
        )
        self._next_id = 1

    def request(self, command, **args):
        # one request at a time, so the next line is always our response
        request = {"id": self._next_id, "command": command, **args}
        self._next_id += 1
        self._process.stdin.write(json.dumps(request) + "\n")
        self._process.stdin.flush()
        line = self._process.stdout.readline()
        if not line:
            raise SystemExit("helper exited without responding: " + self._process.stderr.read())
        response = json.loads(line)
        if not response["ok"]:
            raise SystemExit("%s failed: %s" % (command, response["error"]))
        return response

    def close(self):
        self._process.stdin.close()
        self._process.wait(timeout=TIMEOUT_SECONDS)


def print_tracks(tracks, limit=3):
    for track in tracks[:limit]:
        print("    %-45.45s %-25.25s %4ds  %s" % (
            track["title"], track["artist"], track["duration_seconds"], track["video_id"]))


def check_search_and_stream(helper, query):
    tracks = helper.request("search", query=query)["tracks"]
    print("songs: %r -> %d results, top three:" % (query, len(tracks)))
    print_tracks(tracks)
    if not tracks:
        raise SystemExit("no songs found")

    first = tracks[0]
    stream = helper.request("stream", video_id=first["video_id"])
    print("stream url for %r, expires at %d" % (first["title"], stream["expires_epoch"]))
    request = urllib.request.Request(stream["url"], headers={"Range": "bytes=0-1023"})
    with urllib.request.urlopen(request, timeout=TIMEOUT_SECONDS) as response:
        body = response.read()
        print("  got %d bytes (HTTP %d, %s)" % (len(body), response.status, response.headers.get("Content-Type")))
    if not body:
        raise SystemExit("stream url returned no data")
    check_full_download(stream["url"])
    return first


def check_full_download(url):
    # the relay exists because youtube throttles and cuts long downloads, so time a full read
    started = time.monotonic()
    with urllib.request.urlopen(url, timeout=TIMEOUT_SECONDS) as response:
        expected = int(response.headers["Content-Length"])
        body = response.read()
    print("  full download: %d of %d bytes in %.1f s" % (len(body), expected, time.monotonic() - started))
    if len(body) != expected:
        raise SystemExit("download was %d bytes short" % (expected - len(body)))


def first_card(helper, kind, query):
    cards = helper.request("search", query=query, kind=kind)["cards"]
    print("%s: %r -> %d results, first: %s" % (kind, query, len(cards), cards[0]["title"] if cards else "none"))
    if not cards:
        raise SystemExit("no %s found for %r" % (kind, query))
    return cards[0]


def check_album(helper):
    card = first_card(helper, "albums", "bach cello suites")
    page = helper.request("album", browse_id=card["browse_id"])
    print("  album: %r by %s (%s), %d tracks, cover: %s" % (
        page["title"][:40], page["artist"], page["year"], len(page["tracks"]), "yes" if page["thumbnail_url"] else "NO"))
    if not page["tracks"] or not page["tracks"][0]["thumbnail_url"]:
        raise SystemExit("album has no tracks, or its tracks have no thumbnail")


def check_artist(helper):
    card = first_card(helper, "artists", "radiohead")
    page = helper.request("artist", browse_id=card["browse_id"])
    print("  artist: %s, %d songs, %d albums, %d singles" % (
        page["name"], len(page["songs"]), len(page["albums"]), len(page["singles"])))
    if not page["songs"]:
        raise SystemExit("artist page has no songs")


def check_playlist(helper):
    card = first_card(helper, "playlists", "bach cello")
    page = helper.request("playlist", browse_id=card["browse_id"])
    print("  playlist: %r by %s, %d tracks" % (page["title"][:40], page["author"], len(page["tracks"])))
    if not page["tracks"]:
        raise SystemExit("playlist has no tracks")


def check_home(helper):
    shelves = helper.request("home")["shelves"]
    summary = "; ".join("%s (%d)" % (shelf["title"], len(shelf["items"])) for shelf in shelves)
    print("home: %d shelves: %s" % (len(shelves), summary))
    if not shelves:
        raise SystemExit("home page has no shelves")


def check_radio(helper, track):
    tracks = helper.request("radio", video_id=track["video_id"])["tracks"]
    print("radio for %r: %d songs, top three:" % (track["title"][:40], len(tracks)))
    print_tracks(tracks)
    if not tracks:
        raise SystemExit("radio returned no songs")


def main():
    query = sys.argv[1] if len(sys.argv) > 1 else DEFAULT_QUERY
    helper = HelperProcess()
    try:
        first_song = check_search_and_stream(helper, query)
        check_album(helper)
        check_artist(helper)
        check_playlist(helper)
        check_home(helper)
        check_radio(helper, first_song)
        print("OK")
    finally:
        helper.close()


if __name__ == "__main__":
    main()
