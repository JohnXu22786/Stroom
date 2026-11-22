from pathlib import Path
from io import BytesIO

from PIL import Image
from playwright.sync_api import sync_playwright

ROOT = Path(__file__).resolve().parents[2]
OUTPUT = ROOT / "docs/qa/recording_actions"
BASE_URL = "http://127.0.0.1:8874/"
CAPTURES = (
    (
        "recording",
        320,
        OUTPUT / "recording-320x640-1x-en-light.png",
    ),
    ("paused", 320, OUTPUT / "paused-320x640-1x-en-light.png"),
    (
        "completed",
        320,
        OUTPUT / "completed-320x640-1x-en-light.png",
    ),
    (
        "recording",
        400,
        OUTPUT / "recording-400x640-1x-en-light.png",
    ),
)

OUTPUT.mkdir(parents=True, exist_ok=True)
page_errors = []

with sync_playwright() as playwright:
    browser = playwright.chromium.launch(
        headless=True,
        executable_path="/usr/bin/chromium",
        args=["--no-sandbox", "--disable-dev-shm-usage"],
    )
    context = browser.new_context(
        viewport={"width": 320, "height": 640},
        device_scale_factor=1,
    )
    page = context.new_page()
    page.on("pageerror", lambda error: page_errors.append(str(error)))

    for state, width, output in CAPTURES:
        page.set_viewport_size({"width": width, "height": 640})
        page.goto(f"{BASE_URL}?state={state}", wait_until="load")
        page.evaluate("document.fonts.ready")
        screenshot = None
        for _ in range(40):
            screenshot = page.screenshot()
            image = Image.open(BytesIO(screenshot)).convert("RGB")
            if len(image.getcolors(width * 640) or []) > 10:
                break
            page.wait_for_timeout(500)
        else:
            raise RuntimeError(f"Flutter did not render the {state} state")
        output.write_bytes(screenshot)
        print(
            {
                "output": str(output.relative_to(ROOT)),
                "state": state,
                "viewport_css_px": page.viewport_size,
                "device_pixel_ratio": page.evaluate("devicePixelRatio"),
                "locale": "en-US",
                "theme": "light",
                "text_scale": 1,
                "focus": "none",
                "keyboard": "closed",
                "page_errors": page_errors,
            }
        )

    browser.close()

if page_errors:
    raise RuntimeError(f"Chromium reported page errors: {page_errors}")
