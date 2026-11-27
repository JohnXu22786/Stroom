from io import BytesIO
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

from PIL import Image, ImageStat
from playwright.sync_api import TimeoutError as PlaywrightTimeoutError

from capture_render_readiness import (
    capture_video_frames,
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
        screenshot_seconds=0,
        unrelated_page_image=None,
    ):
        self.screenshots = iter(screenshots)
        self.rendered_texts = iter(rendered_texts)
        self.focus_error = focus_error
        self.screenshot_error = screenshot_error
        self.clock = clock
        self.navigation_seconds = navigation_seconds
        self.screenshot_seconds = screenshot_seconds
        self.unrelated_page_image = unrelated_page_image
        self.last_locator_selector = None
        self.screenshot_count = 0
        self.keyboard_events = []
        self.focused_via_script = False
        self.activation_expression = None
        self.events = []
        self.wait_for_function_count = 0

    def goto(self, _url, wait_until, timeout):
        self.goto_wait_until = wait_until
        self.goto_timeout = timeout
        if self.clock:
            self.clock.now += self.navigation_seconds

    def locator(self, _selector):
        self.last_locator_selector = _selector
        return self

    @property
    def first(self):
        return self

    def evaluate(self, expression, timeout=None):
        self.evaluate_timeout = timeout
        if "element.focus()" in expression and "KeyboardEvent" in expression:
            self.focus_timeout = timeout
            self.focused_via_script = True
            self.activation_expression = expression
            self.events.append("focus")
            self.keyboard_events = [
                event
                for event in ("keydown", "keyup")
                if f'"{event}"' in expression
            ]
            if self.focus_error:
                raise PlaywrightTimeoutError("semantics placeholder did not appear")
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

    def screenshot(self, path=None, timeout=None):
        self.screenshot_timeout = timeout
        self.screenshot_count += 1
        self.events.append("screenshot")
        if self.clock:
            self.clock.now += self.screenshot_seconds
        if self.screenshot_error and self.screenshot_count > 1:
            raise PlaywrightTimeoutError("screenshot timed out")
        try:
            return next(self.screenshots)
        except StopIteration:
            return png_bytes("white")

    def wait_for_timeout(self, milliseconds):
        if self.clock:
            self.clock.now += milliseconds / 1_000


class CaptureRenderReadinessTest(unittest.TestCase):
    def test_nonblank_splash_does_not_satisfy_catcatch_empty_state_readiness(self):
        page = FakePage([png_bytes("navy")], ["Flutter splash screen"])

        with self.assertRaisesRegex(RuntimeError, "Aucune tâche de téléchargement"):
            wait_for_flutter_render(
                page,
                (2, 2),
                "Aucune tâche de téléchargement pour le moment",
                timeout=1,
                poll_interval=0,
            )

        self.assertEqual(page.screenshot_count, 1)
        self.assertEqual(page.keyboard_events, ["keydown", "keyup"])

    def test_catcatch_empty_state_text_and_painted_canvas_satisfy_readiness(self):
        page = FakePage(
            [png_bytes("navy"), png_bytes("navy")],
            ["Aucune tâche de téléchargement pour le moment"],
        )

        wait_for_flutter_render(
            page,
            (2, 2),
            "Aucune tâche de téléchargement pour le moment",
            timeout=1,
            poll_interval=0,
        )

        self.assertEqual(page.screenshot_count, 2)
        self.assertTrue(page.focused_via_script)
        self.assertLessEqual(page.focus_timeout, 1_000)
        self.assertEqual(page.keyboard_events, ["keydown", "keyup"])
        self.assertIn('key: "Enter"', page.activation_expression)
        self.assertLess(
            page.events.index("screenshot"), page.events.index("focus")
        )

    def test_video_frame_manifest_preserves_full_capture_interval(self):
        with tempfile.TemporaryDirectory() as temporary_frames:
            manifest = write_video_frame_manifest(
                Path(temporary_frames),
                [10.37, 15, 20],
                capture_started_at=10,
                capture_deadline=25,
            )
            lines = manifest.read_text(encoding="utf-8").splitlines()

        durations = [float(line.split()[1]) for line in lines if line.startswith("duration ")]
        self.assertEqual(sum(durations), 15)
        self.assertEqual(lines[-1], "file 'frame-0002.png'")

    def test_navigation_and_render_share_one_deadline(self):
        clock = FakeClock(10)
        page = FakePage(
            [png_bytes("navy"), png_bytes("navy")],
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
            [
                png_bytes("white"),
                png_bytes("white"),
                png_bytes("navy"),
                png_bytes("navy"),
            ],
            ["", "", "Stimmen bearbeiten"],
        )

        wait_for_flutter_render(
            page, (2, 2), "Stimmen bearbeiten", timeout=1, poll_interval=0
        )

        self.assertEqual(page.screenshot_count, 4)
        self.assertEqual(page.last_locator_selector, "flt-glass-pane canvas")

    def test_unrelated_page_pixels_do_not_satisfy_flutter_surface_readiness(self):
        page = FakePage(
            [png_bytes("white")],
            ["Stimmen bearbeiten"],
            unrelated_page_image=png_bytes("navy"),
        )

        with self.assertRaisesRegex(RuntimeError, "nonblank"):
            wait_for_flutter_render(
                page,
                (2, 2),
                "Stimmen bearbeiten",
                timeout=0.01,
                poll_interval=0,
            )

        unrelated_page = Image.open(BytesIO(page.unrelated_page_image))
        self.assertGreater(max(ImageStat.Stat(unrelated_page).stddev), 1)
        self.assertEqual(page.last_locator_selector, "flt-glass-pane canvas")

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
        self.assertEqual(page.screenshot_count, 1)

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
        page = FakePage([png_bytes("navy")], [], focus_error=True)

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
            [png_bytes("navy"), png_bytes("navy")],
            ["Stimmen bearbeiten"],
            screenshot_error=True,
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
        self.assertEqual(page.keyboard_events, ["keydown", "keyup"])
        self.assertLessEqual(page.evaluate_timeout, 1_000)
        self.assertLessEqual(page.wait_for_function_timeout, 1_000)
        self.assertLessEqual(page.screenshot_timeout, 1_000)

    def test_stops_after_wall_clock_deadline_before_scheduled_frame_time(self):
        clock = FakeClock(0)
        page = FakePage([], [], clock=clock, screenshot_seconds=0.16)

        with tempfile.TemporaryDirectory() as temporary_frames:
            with patch("capture_render_readiness.time.monotonic", clock.monotonic):
                frame_times = capture_video_frames(
                    page, Path(temporary_frames), 0, 0.25, frame_rate=10
                )

        self.assertEqual(len(frame_times), 2)
        self.assertEqual(page.screenshot_count, 2)


if __name__ == "__main__":
    unittest.main()
