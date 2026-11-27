from io import BytesIO
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

from PIL import Image
from playwright.sync_api import TimeoutError as PlaywrightTimeoutError

from capture_render_readiness import (
    navigate_and_wait_for_flutter_render,
    wait_for_flutter_render,
    write_video_frame_manifest,
)


def png_bytes(color):
    image = Image.new("RGB", (2, 2), color)
    if color != "white":
        image.putpixel((1, 1), (255, 255, 255))
    output = BytesIO()
    image.save(output, format="PNG")
    return output.getvalue()


class FakeClock:
    def __init__(self, now):
        self.now = now

    def monotonic(self):
        return self.now


class FakePage:
    def __init__(
        self,
        screenshots,
        rendered_texts,
        focus_error=False,
        screenshot_error=False,
        clock=None,
        navigation_seconds=0,
    ):
        self.screenshots = iter(screenshots)
        self.rendered_texts = iter(rendered_texts)
        self.focus_error = focus_error
        self.screenshot_error = screenshot_error
        self.clock = clock
        self.navigation_seconds = navigation_seconds
        self.screenshot_count = 0
        self.press_timeout = None
        self.wait_for_function_count = 0

    def goto(self, _url, wait_until, timeout):
        self.goto_wait_until = wait_until
        self.goto_timeout = timeout
        if self.clock:
            self.clock.now += self.navigation_seconds

    def locator(self, _selector):
        return self

    def focus(self, timeout=None):
        self.focus_timeout = timeout
        if self.focus_error:
            raise PlaywrightTimeoutError("semantics placeholder did not appear")

    def press(self, _key, timeout=None):
        self.press_timeout = timeout
        pass

    def evaluate(self, expression, timeout=None):
        self.evaluate_timeout = timeout
        if expression == "body => document.activeElement.blur()":
            return None

    def wait_for_function(self, _expression, *, arg, timeout=None):
        self.wait_for_function_count += 1
        self.wait_for_function_timeout = timeout
        try:
            while arg not in next(self.rendered_texts):
                pass
        except StopIteration:
            raise PlaywrightTimeoutError("expected text did not appear")

    def screenshot(self, timeout=None):
        self.screenshot_timeout = timeout
        self.screenshot_count += 1
        if self.screenshot_error:
            raise PlaywrightTimeoutError("screenshot timed out")
        try:
            return next(self.screenshots)
        except StopIteration:
            return png_bytes("white")

    def wait_for_timeout(self, _milliseconds):
        pass


class CaptureRenderReadinessTest(unittest.TestCase):
    def test_video_frame_manifest_preserves_full_capture_interval(self):
        with tempfile.TemporaryDirectory() as temporary_frames:
            manifest = write_video_frame_manifest(
                Path(temporary_frames), [0, 5, 10], capture_deadline=15
            )
            lines = manifest.read_text(encoding="utf-8").splitlines()

        durations = [float(line.split()[1]) for line in lines if line.startswith("duration ")]
        self.assertEqual(sum(durations), 15)
        self.assertEqual(lines[-1], "file 'frame-0002.png'")

    def test_navigation_and_render_share_one_deadline(self):
        clock = FakeClock(10)
        page = FakePage(
            [png_bytes("navy")],
            ["Topic"],
            clock=clock,
            navigation_seconds=0.6,
        )

        with patch("capture_render_readiness.time.monotonic", clock.monotonic):
            navigate_and_wait_for_flutter_render(
                page, "http://fixture/", (2, 2), "Topic", timeout=1
            )

        self.assertEqual(page.goto_timeout, 1_000)
        self.assertLessEqual(page.focus_timeout, 400)

    def test_waits_until_flutter_paints_nonblank_pixels(self):
        page = FakePage(
            [png_bytes("white"), png_bytes("white"), png_bytes("navy")],
            ["", "", "Stimmen bearbeiten"],
        )

        wait_for_flutter_render(
            page, (2, 2), "Stimmen bearbeiten", timeout=1, poll_interval=0
        )

        self.assertEqual(page.screenshot_count, 3)

    def test_fails_explicitly_when_expected_content_never_appears(self):
        page = FakePage([png_bytes("navy")], [""])

        with self.assertRaisesRegex(RuntimeError, "Stimmen bearbeiten"):
            wait_for_flutter_render(
                page,
                (2, 2),
                "Stimmen bearbeiten",
                timeout=1,
                poll_interval=0,
            )
        self.assertEqual(page.wait_for_function_count, 1)
        self.assertEqual(page.screenshot_count, 0)
    def test_fails_explicitly_when_expected_content_is_still_blank(self):
        page = FakePage([png_bytes("white")], ["Stimmen bearbeiten"])

        with self.assertRaisesRegex(RuntimeError, "nonblank"):
            wait_for_flutter_render(
                page,
                (2, 2),
                "Stimmen bearbeiten",
                timeout=0.01,
                poll_interval=0,
            )

    def test_fails_explicitly_when_flutter_semantics_placeholder_is_missing(self):
        page = FakePage([], [], focus_error=True)

        with self.assertRaisesRegex(RuntimeError, "Stimmen bearbeiten"):
            wait_for_flutter_render(
                page,
                (2, 2),
                "Stimmen bearbeiten",
                timeout=1,
                poll_interval=0,
            )
        self.assertLessEqual(page.focus_timeout, 1_000)

    def test_fails_explicitly_when_screenshot_exceeds_readiness_deadline(self):
        page = FakePage(
            [], ["Stimmen bearbeiten"], screenshot_error=True
        )

        with self.assertRaisesRegex(RuntimeError, "Stimmen bearbeiten"):
            wait_for_flutter_render(
                page,
                (2, 2),
                "Stimmen bearbeiten",
                timeout=1,
                poll_interval=0,
            )
        self.assertLessEqual(page.focus_timeout, 1_000)
        self.assertLessEqual(page.press_timeout, 1_000)
        self.assertLessEqual(page.evaluate_timeout, 1_000)
        self.assertLessEqual(page.wait_for_function_timeout, 1_000)
        self.assertLessEqual(page.screenshot_timeout, 1_000)


if __name__ == "__main__":
    unittest.main()
