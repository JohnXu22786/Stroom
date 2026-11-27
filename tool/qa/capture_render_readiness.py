from io import BytesIO
import time

from PIL import Image, ImageStat
from playwright.sync_api import TimeoutError as PlaywrightTimeoutError


def write_video_frame_manifest(
    frame_directory, frame_times, capture_started_at, capture_deadline
):
    """Write an FFmpeg manifest spanning the complete post-readiness capture."""
    if not frame_times:
        raise ValueError("Cannot encode a video preview without captured frames")

    manifest_frame_times = [capture_started_at, *frame_times[1:]]
    lines = []
    for index, frame_time in enumerate(manifest_frame_times):
        lines.append(f"file 'frame-{index:04d}.png'\n")
        next_time = (
            manifest_frame_times[index + 1]
            if index + 1 < len(manifest_frame_times)
            else capture_deadline
        )
        lines.append(f"duration {max(next_time - frame_time, 0.04):.6f}\n")
    lines.append(f"file 'frame-{len(frame_times) - 1:04d}.png'\n")

    manifest = frame_directory / "frames.txt"
    manifest.write_text("".join(lines), encoding="utf-8")
    return manifest


def capture_video_frames(
    page, frame_directory, capture_started_at, capture_deadline, frame_rate=10
):
    """Capture frames until the wall-clock deadline and return their timestamps."""
    frame_times = []
    frame_number = 0
    next_frame_at = capture_started_at
    while next_frame_at < capture_deadline:
        frame_time = time.monotonic()
        remaining = capture_deadline - frame_time
        if remaining <= 0:
            break

        page.screenshot(
            path=str(frame_directory / f"frame-{frame_number:04d}.png"),
            timeout=max(1, round(remaining * 1_000)),
        )
        frame_times.append(frame_time)
        frame_number += 1
        next_frame_at = capture_started_at + frame_number / frame_rate
        wait_milliseconds = round((next_frame_at - time.monotonic()) * 1_000)
        if wait_milliseconds > 0:
            remaining = capture_deadline - time.monotonic()
            if remaining <= 0:
                break
            page.wait_for_timeout(
                min(wait_milliseconds, max(1, round(remaining * 1_000)))
            )
    return frame_times


def remaining_timeout_ms(deadline, failure_message):
    remaining = deadline - time.monotonic()
    if remaining <= 0:
        raise RuntimeError(failure_message)
    return max(1, round(remaining * 1_000))


def _wait_for_flutter_canvas(
    page, expected_size, deadline, failure_message, poll_interval
):
    while True:
        rendered = Image.open(
            BytesIO(
                page.locator("flt-glass-pane canvas").first.screenshot(
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
        _wait_for_flutter_canvas(
            page, expected_size, deadline, failure_message, poll_interval
        )
        semantics_placeholder = page.locator("flt-semantics-placeholder")
        semantics_placeholder.evaluate(
            """element => {
                element.focus();
                for (const type of ["keydown", "keyup"]) {
                    element.dispatchEvent(new KeyboardEvent(type, {
                        key: "Enter",
                        code: "Enter",
                        bubbles: true,
                    }));
                }
            }""",
            timeout=remaining_timeout_ms(deadline, failure_message),
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
        _wait_for_flutter_canvas(
            page, expected_size, deadline, failure_message, poll_interval
        )
    except PlaywrightTimeoutError as error:
        raise RuntimeError(failure_message) from error
