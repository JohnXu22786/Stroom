from io import BytesIO
from pathlib import Path

from PIL import Image, ImageStat
from playwright.sync_api import sync_playwright


ROOT = Path(__file__).resolve().parents[2]
OUTPUT = ROOT / "docs/ui-constrained-text-qa/tts-format-badge"
OUTPUT.mkdir(parents=True, exist_ok=True)
CASES = [
    ("default-en-320x640-scale1-light", "en-US", 1),
    ("large-fr-320x640-scale4-light", "fr-FR", 4),
]
URL = "http://127.0.0.1:8897/"

with sync_playwright() as playwright:
    browser = playwright.chromium.launch(
        headless=True,
        executable_path="/usr/bin/chromium",
        args=["--no-sandbox", "--disable-dev-shm-usage"],
    )
    for name, locale, scale in CASES:
        page = browser.new_page(
            viewport={"width": 320, "height": 640},
            device_scale_factor=1,
            reduced_motion="reduce",
        )
        errors = []
        page.on("pageerror", lambda error: errors.append(str(error)))
        page.goto(
            f"{URL}?locale={locale}&scale={scale}&theme=light",
            wait_until="load",
            timeout=120_000,
        )
        page.locator("canvas").wait_for(state="visible", timeout=30_000)
        page.wait_for_timeout(1200)
        screenshot = page.screenshot()
        rendered = Image.open(BytesIO(screenshot)).convert("RGB")
        if max(ImageStat.Stat(rendered).stddev) < 1:
            raise RuntimeError("Flutter Web did not render the TTS file list")
        if page.evaluate("devicePixelRatio") != 1:
            raise RuntimeError("Capture device pixel ratio was not 1")
        (OUTPUT / f"{name}.png").write_bytes(screenshot)
        if errors:
            raise RuntimeError(f"Browser reported runtime errors: {errors}")
        print(
            {
                "screenshot": f"{name}.png",
                "viewport_css_px": {"width": 320, "height": 640},
                "device_pixel_ratio": 1,
                "locale": locale,
                "text_scale": scale,
                "theme": "light Material 3",
                "format": "FLAC",
                "page_errors": errors,
            }
        )
        page.close()
    browser.close()
