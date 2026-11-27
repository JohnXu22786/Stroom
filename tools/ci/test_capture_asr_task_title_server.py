import socketserver
import tempfile
import threading
import time
import unittest
from pathlib import Path
from urllib.parse import urlsplit

from tool.qa.capture_asr_task_title import (
    start_fixture_server as start_fixture_web_server,
    wait_for_fixture_server,
)


class FixtureRequestHandler(socketserver.BaseRequestHandler):
    def handle(self):
        request = bytearray()
        while b"\r\n\r\n" not in request:
            request.extend(self.request.recv(4096))

        if self.server.incomplete_headers:
            self.request.sendall(b"HTTP/1.1 200 OK\r\nContent-Length: 16\r\n")
            return

        if self.server.slow_headers:
            self.request.sendall(b"HTTP/1.1 200 OK\r\n")
            for byte in b"Content-Length: 16\r\nConnection: close\r\n\r\n":
                try:
                    self.request.sendall(bytes([byte]))
                except OSError:
                    return
                time.sleep(0.02)
            return

        body = self.server.body
        self.request.sendall(
            b"HTTP/1.1 200 OK\r\n"
            + f"Content-Length: {len(body)}\r\n".encode()
            + b"Connection: close\r\n\r\n"
            + body
        )


class FixtureServer(socketserver.ThreadingTCPServer):
    allow_reuse_address = True
    daemon_threads = True

    def __init__(self, body=b"", slow_headers=False, incomplete_headers=False):
        super().__init__(("127.0.0.1", 0), FixtureRequestHandler)
        self.body = body
        self.slow_headers = slow_headers
        self.incomplete_headers = incomplete_headers


class CaptureAsrTaskTitleServerTest(unittest.TestCase):
    def setUp(self):
        self.temp_dir = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp_dir.cleanup)
        self.fixture_bundle = Path(self.temp_dir.name) / "main.dart.js"
        self.fixture_bundle.write_bytes(b"intended fixture")

    def start_server(self, body=b"", slow_headers=False, incomplete_headers=False):
        http_server = FixtureServer(body, slow_headers, incomplete_headers)
        thread = threading.Thread(target=http_server.serve_forever, daemon=True)
        thread.start()
        self.addCleanup(http_server.server_close)
        self.addCleanup(thread.join)
        self.addCleanup(http_server.shutdown)
        return f"http://127.0.0.1:{http_server.server_address[1]}"

    def start_fixture_web(self, port=0):
        server = start_fixture_web_server(self.temp_dir.name, port=port)
        self.addCleanup(server.server_close)
        self.addCleanup(server.shutdown)
        return server, f"http://127.0.0.1:{server.server_address[1]}"

    def test_waits_until_intended_fixture_bundle_is_served(self):
        _, url = self.start_fixture_web()

        wait_for_fixture_server(self.fixture_bundle, url)

    def test_rejects_a_different_fixture_on_the_port(self):
        url = self.start_server(b"another service")

        with self.assertRaisesRegex(RuntimeError, "different fixture"):
            wait_for_fixture_server(self.fixture_bundle, url)

    def test_reports_port_conflict_even_when_other_server_serves_identical_bundle(self):
        url = self.start_server(b"intended fixture")
        port = urlsplit(url).port

        with self.assertRaisesRegex(RuntimeError, "port may already be in use"):
            start_fixture_web_server(self.temp_dir.name, port=port)

    def test_stops_reading_slow_headers_at_the_readiness_deadline(self):
        url = self.start_server(slow_headers=True)
        started = time.monotonic()

        with self.assertRaisesRegex(RuntimeError, "did not become ready within 0.1 seconds"):
            wait_for_fixture_server(self.fixture_bundle, url, timeout=0.1)

        self.assertLess(time.monotonic() - started, 0.5)

    def test_rejects_a_server_that_closes_during_headers(self):
        url = self.start_server(incomplete_headers=True)

        with self.assertRaisesRegex(RuntimeError, "different fixture"):
            wait_for_fixture_server(self.fixture_bundle, url)


if __name__ == "__main__":
    unittest.main()
