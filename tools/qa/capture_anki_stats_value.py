from io import BytesIO
from pathlib import Path

from PIL import Image, ImageStat
from playwright.sync_api import sync_playwright


ROOT = Path(__file__).resolve().parents[2]
OUTPUT = ROOT / "docs/qa/anki_stats_value"
URL = "http://127.0.0.1:8899/"
CASES = [
    (320, 640, 3, "large-count-320x640-scale3-light.png"),
    (800, 1200, 1, "fitting-count-800x1200-scale1-light.png"),
]
OUTPUT.mkdir(parents=True, exist_ok=True)

with sync_playwright() as playwright:
    browser = playwright.chromium.launch(
        headless=True,
        executable_path="/usr/bin/chromium",
        args=["--no-sandbox", "--disable-dev-shm-usage"],
    )
    for width, height, scale, filename in CASES:
        page = browser.new_page(
            viewport={"width": width, "height": height},
            device_scale_factor=1,
            reduced_motion="reduce",
        )
        errors = []
        page.on("pageerror", lambda error: errors.append(str(error)))
        page.goto(f"{URL}?scale={scale}", wait_until="load", timeout=120_000)
        page.locator("canvas").wait_for(state="visible", timeout=30_000)
        page.wait_for_timeout(1_500)

        screenshot = page.screenshot()
        rendered = Image.open(BytesIO(screenshot)).convert("RGB")
        if rendered.size != (width, height):
            raise RuntimeError(f"Unexpected screenshot size: {rendered.size}")
        if max(ImageStat.Stat(rendered).stddev) < 1:
            raise RuntimeError("Flutter Web did not render the Anki statistics page")
        if page.evaluate("devicePixelRatio") != 1:
            raise RuntimeError("Capture device pixel ratio was not 1")
        (OUTPUT / filename).write_bytes(screenshot)
        if errors:
            raise RuntimeError(f"Browser reported runtime errors: {errors}")
        page.close()
    browser.close()

print(
    {
        "screenshots": [
            {
                "file": name,
                "logical_viewport": f"{width}x{height}",
                "device_pixel_ratio": 1,
                "text_scale": scale,
                "locale": "en-US",
                "theme": "light Material 3",
                "fixture": "local in-memory Anki stats only",
                "reduced_motion": True,
            }
            for width, height, scale, name in CASES
        ]
    }
)
