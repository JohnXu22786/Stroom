import sys
import unittest
from pathlib import Path


sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "tool" / "qa"))

from capture_notification_banner_helpers import require_banner_seen  # noqa: E402


class RequireBannerSeenTest(unittest.TestCase):
    def test_missing_banner_stops_capture_with_clear_error(self):
        with self.assertRaisesRegex(
            RuntimeError,
            "Notification banner was never observed in 500 capture frames.",
        ):
            require_banner_seen(False, 500)


if __name__ == "__main__":
    unittest.main()
