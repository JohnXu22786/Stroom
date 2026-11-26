import unittest
from pathlib import Path
import sys


ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT))

from tool.qa.capture_provider_model_tile import server_command


class CaptureProviderModelTileServerCommandTest(unittest.TestCase):
    def test_server_command_binds_dynamic_port_only_to_loopback(self):
        port = 43210

        command = server_command(port)

        self.assertEqual(
            command,
            [
                "python3",
                "-m",
                "http.server",
                str(port),
                "--bind",
                "127.0.0.1",
                "--directory",
                "/tmp/stroom-provider-model-tile-web",
            ],
        )


if __name__ == "__main__":
    unittest.main()
