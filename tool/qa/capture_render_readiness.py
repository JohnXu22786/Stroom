from io import BytesIO
import time

from PIL import Image, ImageStat


def wait_for_flutter_render(
    page, expected_size, expected_text, timeout=120, poll_interval=0.5
):
    """Wait until the expected Flutter content and a nonblank frame appear."""
    deadline = time.monotonic() + timeout
    page.locator("flt-semantics-placeholder").focus()
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
            raise RuntimeError(
                f"Flutter Web did not render {expected_text!r} on a nonblank "
                f"{expected_size} surface "
                f"within {timeout} seconds"
            )
        page.wait_for_timeout(round(poll_interval * 1_000))
