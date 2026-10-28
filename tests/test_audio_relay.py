# audio relay tests against a fake local googlevideo server that can drop pieces halfway.

import http.server
import pathlib
import sys
import threading
import unittest
import urllib.error
import urllib.parse
import urllib.request

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent.parent / "helper"))

import audio_relay  # noqa: E402

# a bit over 3 pieces; the pattern makes any misplaced byte show up
SONG = bytes(i * 7 % 251 for i in range(3 * audio_relay.PIECE_BYTES + 12345))


class FakeAudioServer:
    """Serves SONG by &range=, cutting the first `drops` responses off halfway."""

    def __init__(self, drops=0):
        self.drops_left = drops
        self.ranges = []
        fake = self

        class Handler(http.server.BaseHTTPRequestHandler):
            def do_GET(self):
                query = urllib.parse.parse_qs(urllib.parse.urlparse(self.path).query)
                first, last = (int(n) for n in query["range"][0].split("-"))
                fake.ranges.append((first, last))
                body = SONG[first:last + 1]
                self.send_response(200)
                self.send_header("Content-Length", str(len(body)))
                self.end_headers()
                if fake.drops_left > 0:
                    fake.drops_left -= 1
                    self.wfile.write(body[:len(body) // 2])
                    self.close_connection = True
                    return
                self.wfile.write(body)

            def log_message(self, format, *args):
                pass

        self._server = http.server.ThreadingHTTPServer(("127.0.0.1", 0), Handler)
        threading.Thread(target=self._server.serve_forever, daemon=True).start()
        self.url = "http://127.0.0.1:%d/videoplayback?id=x" % self._server.server_address[1]

    def close(self):
        self._server.shutdown()
        self._server.server_close()


class AudioRelayTest(unittest.TestCase):
    def setUp(self):
        self._delay = audio_relay.RETRY_DELAY_SECONDS
        audio_relay.RETRY_DELAY_SECONDS = 0

    def tearDown(self):
        audio_relay.RETRY_DELAY_SECONDS = self._delay

    def start_server(self, drops=0):
        server = FakeAudioServer(drops)
        self.addCleanup(server.close)
        return server

    def relay_url(self, server):
        return audio_relay.AudioRelay().add_song(server.url, len(SONG), "audio/webm", {"User-Agent": "test"})

    def fetch(self, url, range_header=None):
        headers = {"Range": range_header} if range_header else {}
        with urllib.request.urlopen(urllib.request.Request(url, headers=headers), timeout=10) as response:
            return response.status, response.headers, response.read()

    def test_whole_song_fetched_in_pieces(self):
        server = self.start_server()
        status, headers, body = self.fetch(self.relay_url(server))
        self.assertEqual(status, 200)
        self.assertEqual(headers["Content-Length"], str(len(SONG)))
        self.assertEqual(body, SONG)
        self.assertEqual(len(server.ranges), 4)
        self.assertTrue(all(last - first < audio_relay.PIECE_BYTES for first, last in server.ranges))

    def test_dropped_piece_resumes_where_it_stopped(self):
        server = self.start_server(drops=2)
        status, headers, body = self.fetch(self.relay_url(server))
        self.assertEqual(body, SONG)
        self.assertEqual(server.ranges[1][0], audio_relay.PIECE_BYTES // 2)

    def test_open_ended_range(self):
        server = self.start_server()
        first = audio_relay.PIECE_BYTES + 100
        status, headers, body = self.fetch(self.relay_url(server), "bytes=%d-" % first)
        self.assertEqual(status, 206)
        self.assertEqual(headers["Content-Range"], "bytes %d-%d/%d" % (first, len(SONG) - 1, len(SONG)))
        self.assertEqual(body, SONG[first:])

    def test_closed_range(self):
        server = self.start_server()
        status, headers, body = self.fetch(self.relay_url(server), "bytes=0-1023")
        self.assertEqual(status, 206)
        self.assertEqual(body, SONG[:1024])

    def test_range_past_end_returns_416(self):
        server = self.start_server()
        with self.assertRaises(urllib.error.HTTPError) as caught:
            self.fetch(self.relay_url(server), "bytes=%d-" % len(SONG))
        caught.exception.close()
        self.assertEqual(caught.exception.code, 416)

    def test_unknown_token_returns_404(self):
        server = self.start_server()
        url = self.relay_url(server)
        with self.assertRaises(urllib.error.HTTPError) as caught:
            self.fetch(url.rsplit("/", 1)[0] + "/nothing")
        caught.exception.close()
        self.assertEqual(caught.exception.code, 404)

    def test_size_from_url(self):
        self.assertEqual(audio_relay.size_from_url("https://x.test/videoplayback?clen=3433755&id=1"), 3433755)
        self.assertEqual(audio_relay.size_from_url("https://x.test/videoplayback?id=1"), 0)


if __name__ == "__main__":
    unittest.main()
