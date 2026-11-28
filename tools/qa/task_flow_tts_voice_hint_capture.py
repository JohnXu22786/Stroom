from io import BytesIO
from pathlib import Path
import time

from PIL import Image, ImageStat
from playwright.sync_api import sync_playwright


ROOT = Path(__file__).resolve().parents[2]
OUTPUT = (
    ROOT
    / "docs/qa/task_flow_tts_voice_hint/tts-voice-hint-en-320x640-1x-light.png"
)
URL = "http://127.0.0.1:8875/"
OUTPUT.parent.mkdir(parents=True, exist_ok=True)

with sync_playwright() as playwright:
    browser = playwright.chromium.launch(
        headless=True,
        executable_path="/usr/bin/chromium",
        args=["--no-sandbox", "--disable-dev-shm-usage"],
    )
    try:
        page = browser.new_page(
            viewport={"width": 320, "height": 640},
            device_scale_factor=1,
        )
        errors = []
        page.on("pageerror", lambda error: errors.append(str(error)))
        page.goto(URL, wait_until="load", timeout=120_000)
        page.locator("flt-semantics-placeholder").evaluate(
            "element => element.click()"
        )

        # Flutter Web does not expose this Text widget in its semantics DOM,
        # so wait for the fixture-specific manual voice field and dialog
        # action. A non-uniform loading screen can't satisfy these checks.
        page.get_by_role("textbox").wait_for(state="visible", timeout=120_000)
        page.get_by_role("button", name="Confirm").wait_for(
            state="visible", timeout=120_000
        )

        deadline = time.monotonic() + 120
        while True:
            screenshot = page.screenshot()
            rendered = Image.open(BytesIO(screenshot)).convert("RGB")
            if max(ImageStat.Stat(rendered).stddev) >= 1:
                break
            if time.monotonic() >= deadline:
                raise RuntimeError("Flutter Web did not render within 120 seconds")
            time.sleep(1)

        if page.evaluate("devicePixelRatio") != 1:
            raise RuntimeError("Capture device pixel ratio was not 1")
        page.evaluate("document.activeElement.blur()")
        page.evaluate(
            """() => new Promise(resolve => requestAnimationFrame(
                () => requestAnimationFrame(resolve)
            ))"""
        )
        screenshot = page.screenshot()
        if errors:
            raise RuntimeError(f"Browser reported runtime errors: {errors}")
        OUTPUT.write_bytes(screenshot)
        print(
            {
                "output": str(OUTPUT.relative_to(ROOT)),
                "viewport_css_px": page.viewport_size,
                "device_pixel_ratio": page.evaluate("devicePixelRatio"),
                "locale": "en_US",
                "theme": "light",
                "text_scale": 1,
                "focus": "none",
                "keyboard": "closed",
                "page_errors": errors,
            }
        )
    finally:
        browser.close()
