import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "tools" / "qa"))

from capture_process_cleanup import cleanup_server  # noqa: E402


class FakeServer:
    def __init__(self, wait_times_out=False):
        self.wait_times_out = wait_times_out
        self.calls = []

    def terminate(self):
        self.calls.append("terminate")

    def wait(self, timeout=None):
        self.calls.append(("wait", timeout))
        if timeout is not None and self.wait_times_out:
            raise subprocess.TimeoutExpired("server", timeout)

    def kill(self):
        self.calls.append("kill")


class CaptureProcessCleanupTest(unittest.TestCase):
    def test_timeout_kills_and_reaps_server_and_cleans_log(self):
        self.assert_cleanup(
            FakeServer(wait_times_out=True),
            ["terminate", ("wait", 10), "kill", ("wait", None)],
        )

    def test_normal_termination_cleans_log_without_killing(self):
        self.assert_cleanup(
            FakeServer(), ["terminate", ("wait", 10)]
        )

    def assert_cleanup(self, server, expected_calls):
        with tempfile.TemporaryDirectory() as directory:
            log_path = Path(directory) / "server.log"
            log_path.write_text("server output", encoding="utf-8")
            server_log = log_path.open("w", encoding="utf-8")

            cleanup_server(server, server_log, log_path)

            self.assertEqual(server.calls, expected_calls)
            self.assertTrue(server_log.closed)
            self.assertFalse(log_path.exists())


if __name__ == "__main__":
    unittest.main()
