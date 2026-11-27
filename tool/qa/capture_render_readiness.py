from io import BytesIO
import time

from PIL import Image, ImageStat
from playwright.sync_api import TimeoutError as PlaywrightTimeoutError


def video_recording_wait_seconds(motion_seconds, page_setup_seconds):
    """Record long enough to cover setup time included in a video seek offset."""
    return motion_seconds + page_setup_seconds


def wait_for_flutter_render(
    page, expected_size, expected_text, timeout=120, poll_interval=0.5
):
    """Wait until the expected Flutter content and a nonblank frame appear."""
    deadline = time.monotonic() + timeout
    failure_message = (
        f"Flutter Web did not render {expected_text!r} on a nonblank "
        f"{expected_size} surface within {timeout} seconds"
    )

    def remaining_timeout_ms():
        remaining = deadline - time.monotonic()
        if remaining <= 0:
            raise RuntimeError(failure_message)
        return max(1, round(remaining * 1_000))

    try:
        semantics_placeholder = page.locator("flt-semantics-placeholder")
        semantics_placeholder.focus(timeout=remaining_timeout_ms())
        semantics_placeholder.press("Enter", timeout=remaining_timeout_ms())
        page.locator("body").evaluate(
            "body => document.activeElement.blur()",
            timeout=remaining_timeout_ms(),
        )
        page.wait_for_function(
            "expected => document.body.innerText.includes(expected)",
            arg=expected_text,
            timeout=remaining_timeout_ms(),
        )
        while True:
            rendered = Image.open(
                BytesIO(page.screenshot(timeout=remaining_timeout_ms()))
            ).convert("RGB")
            if (
                rendered.size == expected_size
                and max(ImageStat.Stat(rendered).stddev) >= 1
            ):
                return
            page.wait_for_timeout(
                min(round(poll_interval * 1_000), remaining_timeout_ms())
            )
    except PlaywrightTimeoutError as error:
        raise RuntimeError(failure_message) from error
