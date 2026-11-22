from pathlib import Path

from playwright.sync_api import sync_playwright

ROOT = Path(__file__).resolve().parents[2]
CAPTURES = (
    (
        1,
        ROOT
        / "docs/qa/voice_editor_actions/voice-editor-actions-de-320x640-scale1-light.png",
    ),
    (
        2,
        ROOT
        / "docs/qa/voice_editor_actions/voice-editor-actions-de-320x640-scale2-light.png",
    ),
)
BASE_URL = "http://127.0.0.1:8874/?theme=light"

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
    errors = []
    page.on("pageerror", lambda error: errors.append(str(error)))
    for scale, output in CAPTURES:
        page.goto(f"{BASE_URL}&scale={scale}", wait_until="load")
        page.wait_for_timeout(8_000)
        page.screenshot(path=str(output))
        print(
            {
                "output": str(output.relative_to(ROOT)),
                "viewport_css_px": page.viewport_size,
                "device_pixel_ratio": page.evaluate("devicePixelRatio"),
                "locale": "de_DE",
                "theme": "light",
                "text_scale": scale,
                "focus": "none",
                "keyboard": "closed",
                "page_errors": errors,
            }
        )
    browser.close()

if errors:
    raise RuntimeError(f"Browser reported runtime errors: {errors}")
