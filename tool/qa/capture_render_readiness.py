from io import BytesIO
import time

from PIL import Image, ImageStat
from playwright.sync_api import TimeoutError as PlaywrightTimeoutError


def wait_for_flutter_render(
    page, expected_size, expected_text, timeout=120, poll_interval=0.5
):
    """Wait until the expected Flutter content and a nonblank frame appear."""
    deadline = time.monotonic() + timeout
    failure_message = (
        f"Flutter Web did not render {expected_text!r} on a nonblank "
        f"{expected_size} surface within {timeout} seconds"
    )
    try:
        page.locator("flt-semantics-placeholder").focus(
            timeout=max(1, round((deadline - time.monotonic()) * 1_000))
        )
    except PlaywrightTimeoutError as error:
        raise RuntimeError(failure_message) from error
    page.keyboard.press("Enter")
    page.evaluate("document.activeElement.blur()")
    while True:
        rendered_text = page.evaluate("document.body.innerText")
        rendered = Image.open(BytesIO(page.screenshot())).convert("RGB")
        if (
            expected_text in rendered_text
            and rendered.size == expected_size
            and max(ImageStat.Stat(rendered).stddev) >= 1
        ):
            return
        if time.monotonic() >= deadline:
            raise RuntimeError(failure_message)
        page.wait_for_timeout(round(poll_interval * 1_000))
