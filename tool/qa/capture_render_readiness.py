from io import BytesIO
import time

from PIL import Image, ImageStat
from playwright.sync_api import TimeoutError as PlaywrightTimeoutError


def video_preview_timing(recording_started_at, motion_started_at, motion_seconds):
    """Return the seek offset and duration for a preview after page readiness."""
    return motion_started_at - recording_started_at, motion_seconds


def remaining_timeout_ms(deadline, failure_message):
    remaining = deadline - time.monotonic()
    if remaining <= 0:
        raise RuntimeError(failure_message)
    return max(1, round(remaining * 1_000))


def navigate_and_wait_for_flutter_render(
    page, url, expected_size, expected_text, timeout=120, poll_interval=0.5
):
    """Navigate and wait for the expected Flutter UI under one deadline."""
    deadline = time.monotonic() + timeout
    failure_message = (
        f"Flutter Web did not render {expected_text!r} on a nonblank "
        f"{expected_size} surface within {timeout} seconds"
    )
    try:
        page.goto(
            url,
            wait_until="load",
            timeout=remaining_timeout_ms(deadline, failure_message),
        )
    except PlaywrightTimeoutError as error:
        raise RuntimeError(failure_message) from error
    wait_for_flutter_render(
        page,
        expected_size,
        expected_text,
        timeout=timeout,
        poll_interval=poll_interval,
        deadline=deadline,
    )


def wait_for_flutter_render(
    page, expected_size, expected_text, timeout=120, poll_interval=0.5, deadline=None
):
    """Wait until the expected Flutter content and a nonblank frame appear."""
    if deadline is None:
        deadline = time.monotonic() + timeout
    failure_message = (
        f"Flutter Web did not render {expected_text!r} on a nonblank "
        f"{expected_size} surface within {timeout} seconds"
    )

    try:
        semantics_placeholder = page.locator("flt-semantics-placeholder")
        semantics_placeholder.focus(
            timeout=remaining_timeout_ms(deadline, failure_message)
        )
        semantics_placeholder.press(
            "Enter", timeout=remaining_timeout_ms(deadline, failure_message)
        )
        page.locator("body").evaluate(
            "body => document.activeElement.blur()",
            timeout=remaining_timeout_ms(deadline, failure_message),
        )
        page.wait_for_function(
            "expected => document.body.innerText.includes(expected)",
            arg=expected_text,
            timeout=remaining_timeout_ms(deadline, failure_message),
        )
        while True:
            rendered = Image.open(
                BytesIO(
                    page.screenshot(
                        timeout=remaining_timeout_ms(deadline, failure_message)
                    )
                )
            ).convert("RGB")
            if (
                rendered.size == expected_size
                and max(ImageStat.Stat(rendered).stddev) >= 1
            ):
                return
            page.wait_for_timeout(
                min(
                    round(poll_interval * 1_000),
                    remaining_timeout_ms(deadline, failure_message),
                )
            )
    except PlaywrightTimeoutError as error:
        raise RuntimeError(failure_message) from error
