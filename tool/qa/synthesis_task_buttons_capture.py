from pathlib import Path
from playwright.sync_api import sync_playwright

ROOT = Path(__file__).resolve().parents[2]
OUTPUT = ROOT / "docs/qa/synthesis_task_buttons"
URL = "http://127.0.0.1:8877"
OUTPUT.mkdir(parents=True, exist_ok=True)


def main():
    errors = []
    with sync_playwright() as playwright:
        browser = playwright.chromium.launch(
            headless=True,
            executable_path="/usr/bin/chromium",
            args=["--no-sandbox", "--disable-dev-shm-usage"],
        )
        context = browser.new_context(
            viewport={"width": 320, "height": 640},
            device_scale_factor=1,
            reduced_motion="reduce",
        )
        for status in ("paused", "failed", "completed"):
            page = context.new_page()
            page.on("pageerror", lambda error: errors.append(str(error)))
            page.goto(
                f"{URL}/?status={status}&locale=zh-CN&scale=2.5&theme=light",
                wait_until="load",
                timeout=180_000,
            )
            page.wait_for_timeout(4_000)
            if page.evaluate("devicePixelRatio") != 1:
                raise RuntimeError("Expected device scale factor 1")
            page.screenshot(path=str(OUTPUT / f"{status}-zh-CN-320x640-scale2_5.png"))
            page.close()
        context.close()
        browser.close()
    if errors:
        raise RuntimeError(f"Browser reported page errors: {errors}")
    print(
        {
            "viewport_css_px": {"width": 320, "height": 640},
            "device_pixel_ratio": 1,
            "locale": "zh-CN",
            "theme": "light",
            "text_scale": 2.5,
            "focus": "none",
            "keyboard": "closed",
            "states": ["paused", "failed", "completed"],
        }
    )


if __name__ == "__main__":
    main()
