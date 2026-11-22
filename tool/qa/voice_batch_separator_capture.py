from pathlib import Path
from io import BytesIO
import time

from playwright.sync_api import sync_playwright
from PIL import Image, ImageStat


ROOT = Path(__file__).resolve().parents[2]
OUTPUT = (
    ROOT
    / "docs/qa/vertical_voice_separator/voice-batch-separator-de-320x640-1x-light.png"
)
URL = "http://127.0.0.1:8874/?theme=light"
OUTPUT.parent.mkdir(parents=True, exist_ok=True)

with sync_playwright() as playwright:
    browser = playwright.chromium.launch(
        headless=True,
        executable_path="/usr/bin/chromium",
        args=["--no-sandbox", "--disable-dev-shm-usage"],
    )
    page = browser.new_page(
        viewport={"width": 320, "height": 640},
        device_scale_factor=1,
    )
    errors = []
    page.on("pageerror", lambda error: errors.append(str(error)))
    page.goto(URL, wait_until="load", timeout=120_000)
    page.locator("flt-semantics-placeholder").wait_for(timeout=120_000)

    # The debug web server can return its shell before Flutter paints the app.
    # Wait for actual nonblank pixels so a late first frame cannot be captured.
    deadline = time.monotonic() + 120
    while True:
        rendered = Image.open(BytesIO(page.screenshot())).convert("RGB")
        if max(ImageStat.Stat(rendered).stddev) >= 1:
            break
        if time.monotonic() >= deadline:
            raise RuntimeError("Flutter Web did not render within 120 seconds")
        time.sleep(1)

    accessibility_button = page.locator("flt-semantics-placeholder")
    accessibility_button.focus()
    page.keyboard.press("Enter")
    page.wait_for_function("document.body.innerText.includes('Tabulator')")

    # Open the native dropdown and select the full German vertical-bar label.
    page.mouse.click(140, 128)
    page.wait_for_timeout(500)
    page.mouse.click(130, 270)
    page.wait_for_function(
        "document.body.innerText.includes('Senkrechter Strich (|)')"
    )
    page.wait_for_timeout(500)
    page.mouse.click(307, 600)
    page.evaluate("document.activeElement.blur()")
    screenshot = page.screenshot()
    image = Image.open(BytesIO(screenshot)).convert("RGB")
    if max(ImageStat.Stat(image).stddev) < 1:
        raise RuntimeError("Flutter Web produced a blank screenshot")
    OUTPUT.write_bytes(screenshot)
    print(
        {
            "output": str(OUTPUT.relative_to(ROOT)),
            "viewport_css_px": page.viewport_size,
            "device_pixel_ratio": page.evaluate("devicePixelRatio"),
            "locale": "de_DE",
            "theme": "light",
            "text_scale": 1,
            "focus": "none",
            "keyboard": "closed",
            "page_errors": errors,
        }
    )
    browser.close()

if errors:
    raise RuntimeError(f"Browser reported runtime errors: {errors}")
