from io import BytesIO
import unittest

from PIL import Image
from playwright.sync_api import TimeoutError as PlaywrightTimeoutError

from capture_render_readiness import (
    video_recording_wait_seconds,
    wait_for_flutter_render,
)


def png_bytes(color):
    image = Image.new("RGB", (2, 2), color)
    if color != "white":
        image.putpixel((1, 1), (255, 255, 255))
    output = BytesIO()
    image.save(output, format="PNG")
    return output.getvalue()


class FakePage:
    def __init__(self, screenshots, rendered_texts, focus_error=False):
        self.screenshots = iter(screenshots)
        self.rendered_texts = iter(rendered_texts)
        self.focus_error = focus_error
        self.screenshot_count = 0
        self.keyboard = self

    def locator(self, _selector):
        return self

    def focus(self, timeout):
        self.focus_timeout = timeout
        if self.focus_error:
            raise PlaywrightTimeoutError("semantics placeholder did not appear")

    def press(self, _key):
        pass

    def evaluate(self, expression):
        if expression == "document.activeElement.blur()":
            return None
        try:
            return next(self.rendered_texts)
        except StopIteration:
            return ""

    def screenshot(self):
        self.screenshot_count += 1
        try:
            return next(self.screenshots)
        except StopIteration:
            return png_bytes("white")

    def wait_for_timeout(self, _milliseconds):
        pass


class CaptureRenderReadinessTest(unittest.TestCase):
    def test_video_recording_covers_page_setup_before_trim_offset(self):
        self.assertEqual(video_recording_wait_seconds(15, 0.4), 15.4)

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
                timeout=0,
                poll_interval=0,
            )
    def test_fails_explicitly_when_expected_content_is_still_blank(self):
        page = FakePage([png_bytes("white")], ["Stimmen bearbeiten"])

        with self.assertRaisesRegex(RuntimeError, "nonblank"):
            wait_for_flutter_render(
                page,
                (2, 2),
                "Stimmen bearbeiten",
                timeout=0,
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


if __name__ == "__main__":
    unittest.main()
