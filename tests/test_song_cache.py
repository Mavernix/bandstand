# song cache tests: downloads into a temporary folder from the fake googlevideo server,
# serving from disk through the relay, eviction, and remembered yt-dlp lookups.

import http.client
import json
import os
import pathlib
import sys
import tempfile
import threading
import time
import unittest
import urllib.error
import urllib.request

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent.parent / "helper"))

import audio_relay  # noqa: E402
import song_cache  # noqa: E402
import streams  # noqa: E402
from test_audio_relay import SONG, FakeAudioServer  # noqa: E402

VIDEO_ID = "dQw4w9WgXcQ"


def wait_until(condition, timeout=10):
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        if condition():
            return True
        time.sleep(0.01)
    return False


def fetch(url, range_header=None):
    headers = {"Range": range_header} if range_header else {}
    with urllib.request.urlopen(urllib.request.Request(url, headers=headers), timeout=10) as response:
        return response.status, response.headers, response.read()


class CacheTestCase(unittest.TestCase):
    def setUp(self):
        self._delay = audio_relay.RETRY_DELAY_SECONDS
        audio_relay.RETRY_DELAY_SECONDS = 0
        folder = tempfile.TemporaryDirectory()
        self.addCleanup(folder.cleanup)
        self.directory = os.path.join(folder.name, "audio")
        self.cache = song_cache.SongCache(self.directory, 64 * 1024 * 1024)
        # only songs the player is on get downloaded
        self.cache.want(song_cache.PLAYING, VIDEO_ID)

    def tearDown(self):
        audio_relay.RETRY_DELAY_SECONDS = self._delay

    def start_server(self, drops=0):
        server = FakeAudioServer(drops)
        self.addCleanup(server.close)
        return server

    def song(self, url, video_id=VIDEO_ID):
        return audio_relay.Song(url, len(SONG), "audio/webm", {"User-Agent": "test"}, video_id)

    def download_and_wait(self, song):
        download = self.cache.download(song, 215)
        self.assertIsNotNone(download)
        # it's forgotten once it ended, done or failed
        self.assertTrue(wait_until(lambda: song.video_id not in self.cache._downloads))
        return download

    def files(self):
        return sorted(os.listdir(self.directory)) if os.path.isdir(self.directory) else []


class DownloadTest(CacheTestCase):
    def test_download_keeps_the_whole_song(self):
        server = self.start_server(drops=1)
        self.download_and_wait(self.song(server.url))

        cached = self.cache.cached(VIDEO_ID)
        self.assertIsNotNone(cached)
        self.assertEqual((cached.size, cached.content_type, cached.duration_seconds), (len(SONG), "audio/webm", 215))
        self.assertEqual(pathlib.Path(cached.path).read_bytes(), SONG)
        self.assertEqual(self.files(), [VIDEO_ID + ".audio", VIDEO_ID + ".json"])

    def test_second_download_of_the_same_song_is_the_running_one(self):
        server = self.start_server()
        with self.cache.download_slots, self.cache.download_slots:  # keeps both downloads waiting
            first = self.cache.download(self.song(server.url), 0)
            self.assertIs(self.cache.download(self.song(server.url), 0), first)
        self.assertTrue(wait_until(lambda: self.cache.cached(VIDEO_ID) is not None))

    def test_failed_download_leaves_nothing(self):
        # nothing listens on a server that was closed
        server = FakeAudioServer()
        server.close()
        self.download_and_wait(self.song(server.url))
        self.assertIsNone(self.cache.cached(VIDEO_ID))
        self.assertEqual(self.files(), [])

    def test_strange_video_ids_are_never_file_names(self):
        server = self.start_server()
        for video_id in ("../escape", "a/b", "", "x.audio", VIDEO_ID + "\n"):
            with self.subTest(video_id=video_id):
                self.assertIsNone(self.cache.download(self.song(server.url, video_id), 0))
                self.assertIsNone(self.cache.cached(video_id))

    def test_skipped_song_stops_downloading(self):
        server = self.start_server()
        with self.cache.download_slots, self.cache.download_slots:  # keeps the download waiting
            self.cache.want(song_cache.PLAYING, VIDEO_ID)
            download = self.cache.download(self.song(server.url), 0)
            self.cache.want(song_cache.PLAYING, "otherSong01")
            self.assertTrue(download.cancelled)
        self.assertTrue(wait_until(lambda: VIDEO_ID not in self.cache._downloads))
        self.assertIsNone(self.cache.cached(VIDEO_ID))
        self.assertEqual(self.files(), [])

    def test_song_coming_up_that_starts_playing_keeps_downloading(self):
        server = self.start_server()
        with self.cache.download_slots, self.cache.download_slots:
            self.cache.want(song_cache.COMING_UP, VIDEO_ID)
            download = self.cache.download(self.song(server.url), 0)
            self.cache.want(song_cache.PLAYING, VIDEO_ID)
            self.cache.want(song_cache.COMING_UP, "otherSong01")
            self.assertFalse(download.cancelled)
        self.assertTrue(wait_until(lambda: self.cache.cached(VIDEO_ID) is not None))

    def test_going_back_to_a_skipped_song_downloads_it_again(self):
        server = self.start_server()
        with self.cache.download_slots, self.cache.download_slots:
            self.cache.want(song_cache.PLAYING, VIDEO_ID)
            skipped = self.cache.download(self.song(server.url), 0)
            self.cache.want(song_cache.PLAYING, "otherSong01")
            self.cache.want(song_cache.PLAYING, VIDEO_ID)
            again = self.cache.download(self.song(server.url), 0)
            self.assertIsNot(again, skipped)
        self.assertTrue(wait_until(lambda: self.cache.cached(VIDEO_ID) is not None))
        self.assertEqual(self.files(), [VIDEO_ID + ".audio", VIDEO_ID + ".json"])

    def test_skipping_past_the_song_coming_up_stops_its_download(self):
        server = self.start_server()
        with self.cache.download_slots, self.cache.download_slots:
            self.cache.want(song_cache.COMING_UP, "comingUp001")
            coming_up = self.cache.download(self.song(server.url, "comingUp001"), 0)
            # next, and next again before anything is prepared
            self.cache.want(song_cache.PLAYING, "comingUp001")
            self.cache.want(song_cache.PLAYING, "afterThat01")
            self.assertTrue(coming_up.cancelled)

    def test_cancel_stops_a_download_that_keeps_retrying(self):
        server = FakeAudioServer()
        server.close()
        audio_relay.RETRY_DELAY_SECONDS = 1  # would take MAX_STALLED_ATTEMPTS seconds to give up
        download = self.cache.download(self.song(server.url), 0)
        self.assertTrue(wait_until(lambda: download._running))
        self.cache.want(song_cache.PLAYING, "otherSong01")
        self.assertTrue(wait_until(lambda: VIDEO_ID not in self.cache._downloads, timeout=2))

    def test_song_skipped_while_it_was_looked_up_isnt_downloaded(self):
        server = self.start_server()
        self.cache.want(song_cache.PLAYING, "otherSong01")
        self.assertIsNone(self.cache.download(self.song(server.url), 0))
        self.assertEqual(self.files(), [])

    def test_download_of_another_file_replaces_the_running_one(self):
        # a newer lookup that youtube answered with another format
        server = self.start_server()
        with self.cache.download_slots, self.cache.download_slots:
            older = self.cache.download(self.song(server.url), 0)
            other_format = audio_relay.Song(server.url, len(SONG), "audio/mp4", {}, VIDEO_ID)
            newer = self.cache.download(other_format, 0)
            self.assertIsNot(newer, older)
            self.assertTrue(older.cancelled)

    def test_failed_download_has_no_file_to_read(self):
        server = FakeAudioServer()
        server.close()
        download = self.download_and_wait(self.song(server.url))
        self.assertIsNone(download.open())

    def test_song_bigger_than_the_cache_is_not_kept(self):
        server = self.start_server()
        cache = song_cache.SongCache(self.directory, len(SONG) - 1)
        self.assertIsNone(cache.download(self.song(server.url), 0))

    def test_size_mismatch_is_not_cached(self):
        server = self.start_server()
        self.download_and_wait(self.song(server.url))
        with open(os.path.join(self.directory, VIDEO_ID + ".audio"), "ab") as file:
            file.write(b"x")
        self.assertIsNone(self.cache.cached(VIDEO_ID))


class RelayFromDiskTest(CacheTestCase):
    def cached_url(self, server):
        self.download_and_wait(self.song(server.url))
        server.ranges.clear()
        relay = audio_relay.AudioRelay(self.cache)
        return relay.add_file(self.cache.cached(VIDEO_ID))

    def test_cached_song_is_served_without_youtube(self):
        server = self.start_server()
        url = self.cached_url(server)
        status, headers, body = fetch(url)
        self.assertEqual((status, headers["Content-Length"], body), (200, str(len(SONG)), SONG))
        self.assertEqual(server.ranges, [])

    def test_cached_song_serves_ranges(self):
        server = self.start_server()
        url = self.cached_url(server)
        first = audio_relay.PIECE_BYTES + 100
        status, headers, body = fetch(url, "bytes=%d-" % first)
        self.assertEqual(status, 206)
        self.assertEqual(headers["Content-Range"], "bytes %d-%d/%d" % (first, len(SONG) - 1, len(SONG)))
        self.assertEqual(body, SONG[first:])
        self.assertEqual(fetch(url, "bytes=0-1023")[2], SONG[:1024])

        with self.assertRaises(urllib.error.HTTPError) as caught:
            fetch(url, "bytes=%d-" % len(SONG))
        caught.exception.close()
        self.assertEqual(caught.exception.code, 416)

    def test_playing_while_downloading_gets_the_whole_song_and_keeps_it(self):
        server = self.start_server(drops=1)
        relay = audio_relay.AudioRelay(self.cache)
        song = self.song(server.url)
        download = self.cache.download(song, 215)
        url = relay.add_song(song, download)

        status, headers, body = fetch(url)
        self.assertEqual(body, SONG)
        self.assertEqual(fetch(url, "bytes=%d-" % (2 * audio_relay.PIECE_BYTES))[2], SONG[2 * audio_relay.PIECE_BYTES:])
        self.assertTrue(wait_until(lambda: self.cache.cached(VIDEO_ID) is not None))
        # the player mostly reads the download's copy instead of asking youtube again
        fetched = sum(last - first + 1 for first, last in server.ranges)
        self.assertLess(fetched, 2 * len(SONG))


class EvictTest(CacheTestCase):
    def keep(self, video_id, size, age):
        os.makedirs(self.directory, exist_ok=True)
        audio = os.path.join(self.directory, video_id + ".audio")
        pathlib.Path(audio).write_bytes(b"x" * size)
        pathlib.Path(self.directory, video_id + ".json").write_text(
            json.dumps({"size": size, "content_type": "audio/webm", "duration_seconds": 1}))
        then = time.time() - age
        os.utime(audio, (then, then))

    def test_oldest_songs_go_first(self):
        self.keep("old", 400, age=300)
        self.keep("middle", 400, age=200)
        self.keep("new", 400, age=100)
        song_cache.SongCache(self.directory, 900).evict()
        self.assertEqual(self.files(), ["middle.audio", "middle.json", "new.audio", "new.json"])

    def test_playing_a_song_makes_it_recent(self):
        self.keep("old", 400, age=300)
        self.keep("new", 400, age=100)
        cache = song_cache.SongCache(self.directory, 500)
        self.assertIsNotNone(cache.cached("old"))
        cache.evict()
        self.assertEqual(self.files(), ["old.audio", "old.json"])

    def test_songs_being_served_are_kept(self):
        self.keep("old", 400, age=300)
        self.keep("new", 400, age=100)
        cache = song_cache.SongCache(self.directory, 500)
        cache.hold("old")
        cache.evict()
        self.assertEqual(self.files(), ["old.audio", "old.json"])

    def test_songs_the_relay_hands_out_are_kept(self):
        self.keep("old", 400, age=300)
        self.keep("new", 400, age=100)
        cache = song_cache.SongCache(self.directory, 500)
        audio_relay.AudioRelay(cache).add_file(cache.cached("old"))
        os.utime(os.path.join(self.directory, "old.audio"), (0, 0))  # played longest ago, still
        cache.evict()
        self.assertEqual(self.files(), ["old.audio", "old.json"])

    def test_songs_the_relay_let_go_of_can_go(self):
        self.keep("old", 400, age=300)
        self.keep("new", 400, age=100)
        cache = song_cache.SongCache(self.directory, 500)
        relay = audio_relay.AudioRelay(cache)
        relay.add_file(cache.cached("old"))
        os.utime(os.path.join(self.directory, "old.audio"), (0, 0))
        for _ in range(audio_relay.MAX_SONGS):
            relay.add_file(cache.cached("new"))
        cache.evict()
        self.assertEqual(self.files(), ["new.audio", "new.json"])

    def test_leftovers_are_removed(self):
        self.keep("kept", 10, age=0)
        cut = pathlib.Path(self.directory, "cut.k3x9.audio.part")
        cut.write_bytes(b"x")
        then = time.time() - song_cache.LEFTOVER_AFTER_SECONDS - 60
        os.utime(cut, (then, then))
        pathlib.Path(self.directory, "lonely.json").write_text("{}")
        self.cache.evict()
        self.assertEqual(self.files(), ["kept.audio", "kept.json"])

    def test_another_bandstands_download_is_left_alone(self):
        self.keep("kept", 10, age=0)
        pathlib.Path(self.directory, "busy.k3x9.audio.part").write_bytes(b"x")
        self.cache.evict()
        self.assertEqual(self.files(), ["busy.k3x9.audio.part", "kept.audio", "kept.json"])

    def test_missing_folder_is_fine(self):
        self.cache.evict()
        self.assertEqual(self.files(), [])


class FakeYtDlpStreams(streams.YtDlpStreams):
    def __init__(self, relay, cache, url):
        super().__init__(relay, cache)
        self.url = url
        self.size = len(SONG)
        self.extracted = []

    def _extract_info(self, video_id):
        self.extracted.append(video_id)
        return {"url": self.url, "filesize": self.size, "ext": "webm", "duration": 215, "http_headers": {}}


class StreamsTest(CacheTestCase):
    def make_streams(self, server, expires_in, cache=True):
        url = server.url + "&expire=%d" % (time.time() + expires_in)
        relay = audio_relay.AudioRelay(self.cache if cache else None)
        return FakeYtDlpStreams(relay, self.cache if cache else None, url)

    def test_remembered_url_that_stopped_working_is_not_handed_out(self):
        # as after moving to another network: the url looked up before doesn't answer any more
        first = self.start_server()
        found = self.make_streams(first, expires_in=6 * 3600, cache=False)
        found.find_audio(VIDEO_ID)
        first.close()
        found.url = self.start_server().url + "&expire=%d" % (time.time() + 6 * 3600)
        self.assertEqual(fetch(found.find_audio(VIDEO_ID)["url"])[2], SONG)
        self.assertEqual(found.extracted, [VIDEO_ID, VIDEO_ID])

    def test_url_the_player_gets_straight_from_youtube_is_not_remembered(self):
        # without a size the relay can't serve it, so nothing would notice it failing
        found = self.make_streams(self.start_server(), expires_in=6 * 3600, cache=False)
        found.size = None
        found.find_audio(VIDEO_ID)
        found.find_audio(VIDEO_ID)
        self.assertEqual(found.extracted, [VIDEO_ID, VIDEO_ID])

    def test_fresh_lookup_is_reused(self):
        found = self.make_streams(self.start_server(), expires_in=6 * 3600, cache=False)
        found.find_audio(VIDEO_ID)
        found.find_audio(VIDEO_ID)
        self.assertEqual(found.extracted, [VIDEO_ID])

    def test_lookup_about_to_expire_is_done_again(self):
        found = self.make_streams(self.start_server(), expires_in=60, cache=False)
        found.find_audio(VIDEO_ID)
        found.find_audio(VIDEO_ID)
        self.assertEqual(found.extracted, [VIDEO_ID, VIDEO_ID])

    def test_lookup_whose_url_stopped_working_is_done_again(self):
        # youtube refusing the url, as when it only works from the network it was looked up on
        server = FakeAudioServer()
        server.close()
        found = self.make_streams(server, expires_in=6 * 3600, cache=False)
        for _ in range(2):
            # the relay closes the connection short of the song
            with self.assertRaises(http.client.IncompleteRead):
                fetch(found.find_audio(VIDEO_ID)["url"])
        self.assertEqual(found.extracted, [VIDEO_ID, VIDEO_ID])

    def test_song_asked_for_twice_at_once_is_looked_up_once(self):
        found = self.make_streams(self.start_server(), expires_in=6 * 3600, cache=False)
        answer_lookup = threading.Event()
        extract = found._extract_info

        def slow_extract(video_id):
            answer_lookup.wait(10)
            return extract(video_id)

        found._extract_info = slow_extract
        both = [threading.Thread(target=found.prepare, args=(VIDEO_ID,)) for _ in range(2)]
        for thread in both:
            thread.start()
        self.assertTrue(wait_until(lambda: VIDEO_ID in found._pending))
        answer_lookup.set()
        for thread in both:
            thread.join(10)
        self.assertEqual(found.extracted, [VIDEO_ID])

    def test_without_a_cache_nothing_is_kept(self):
        found = self.make_streams(self.start_server(), expires_in=6 * 3600, cache=False)
        self.assertEqual(fetch(found.find_audio(VIDEO_ID)["url"])[2], SONG)
        self.assertEqual(found.prepare(VIDEO_ID), {})
        self.assertEqual(self.files(), [])

    def test_prepare_keeps_the_song_and_playing_it_needs_no_yt_dlp(self):
        server = self.start_server()
        found = self.make_streams(server, expires_in=6 * 3600)
        self.assertEqual(found.prepare(VIDEO_ID), {})
        self.assertTrue(wait_until(lambda: self.cache.cached(VIDEO_ID) is not None))

        # as after a restart: nothing remembered but the disk
        again = self.make_streams(server, expires_in=6 * 3600)
        server.ranges.clear()
        answer = again.find_audio(VIDEO_ID)
        self.assertEqual(again.extracted, [])
        self.assertEqual((answer["expires_epoch"], answer["duration_seconds"]), (0, 215))
        self.assertEqual(fetch(answer["url"])[2], SONG)
        self.assertEqual(server.ranges, [])

    def test_playing_keeps_the_song(self):
        found = self.make_streams(self.start_server(), expires_in=6 * 3600)
        answer = found.find_audio(VIDEO_ID)
        self.assertEqual(fetch(answer["url"])[2], SONG)
        self.assertTrue(wait_until(lambda: self.cache.cached(VIDEO_ID) is not None))


if __name__ == "__main__":
    unittest.main()
