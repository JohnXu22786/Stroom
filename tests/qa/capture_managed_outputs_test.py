import sys
import tempfile
import unittest
from pathlib import Path


sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "tools" / "qa"))

from capture_managed_outputs import (  # noqa: E402
    COMPACT_ROW_OUTPUT_PATTERNS,
    RESPONSIVE_MEDIA_OUTPUT_PATTERNS,
    CaptureOutputs,
)


class CaptureManagedOutputsTest(unittest.TestCase):
    def test_compact_row_rerun_removes_only_managed_pngs_and_reports_current_files(self):
        with tempfile.TemporaryDirectory() as directory:
            output = Path(directory)
            stale_capture = output / "voice-index-fitting-1x.png"
            unrelated_capture = output / "voice-index-design-reference.png"
            stale_capture.write_bytes(b"stale")
            unrelated_capture.write_bytes(b"keep")

            captures = CaptureOutputs(output, COMPACT_ROW_OUTPUT_PATTERNS)
            captures.clear()
            captures.write("voice-index-scaled-high-count-2x.png", b"current")

            self.assertFalse(stale_capture.exists())
            self.assertEqual(unrelated_capture.read_bytes(), b"keep")
            self.assertEqual(captures.names, ["voice-index-scaled-high-count-2x.png"])

    def test_responsive_media_rerun_clears_images_and_video_and_reports_current_files(self):
        with tempfile.TemporaryDirectory() as directory:
            output = Path(directory)
            stale_image = output / "media-picker-fr-320x640-scale1-light.png"
            stale_video = output / "media-picker-fr-320x640-scale3-reveal.webm"
            unrelated_capture = output / "media-picker-fr-320x640-scale2-light.png"
            stale_image.write_bytes(b"stale image")
            stale_video.write_bytes(b"stale video")
            unrelated_capture.write_bytes(b"keep")

            captures = CaptureOutputs(output, RESPONSIVE_MEDIA_OUTPUT_PATTERNS)
            captures.clear()
            (output / "mermaid-loading-fr-320x640-scale1-light.png").write_bytes(
                b"current"
            )
            captures.record("mermaid-loading-fr-320x640-scale1-light.png")

            self.assertFalse(stale_image.exists())
            self.assertFalse(stale_video.exists())
            self.assertEqual(unrelated_capture.read_bytes(), b"keep")
            self.assertEqual(
                captures.names, ["mermaid-loading-fr-320x640-scale1-light.png"]
            )


if __name__ == "__main__":
    unittest.main()
