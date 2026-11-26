from pathlib import Path
from playwright.sync_api import sync_playwright

ROOT = Path(__file__).resolve().parents[2]
OUTPUT = ROOT / "docs/qa/task_list_error_detail"
URL = "http://127.0.0.1:8878"
OUTPUT.mkdir(parents=True, exist_ok=True)


def main():
    errors = []
    captures = (
        ("task-detail-de-240x640-scale2_5.png", 240, 640, "de", 2.5, "restoring", False),
        ("task-detail-en-700x640-scale1.png", 700, 640, "en", 1, "ready", True),
    )
    with sync_playwright() as playwright:
        browser = playwright.chromium.launch(
            headless=True,
            executable_path="/usr/bin/chromium",
            args=["--no-sandbox", "--disable-dev-shm-usage"],
        )
        for filename, width, height, locale, scale, ownership, reduce_motion in captures:
            motion = "reduce" if reduce_motion else "normal"
            context = browser.new_context(
                viewport={"width": width, "height": height},
                device_scale_factor=1,
                reduced_motion="reduce" if reduce_motion else "no-preference",
            )
            page = context.new_page()
            page.on("pageerror", lambda error: errors.append(str(error)))
            page.goto(
                f"{URL}/?locale={locale}&scale={scale}&ownership={ownership}&motion={motion}",
                wait_until="load",
                timeout=180_000,
            )
            page.wait_for_timeout(20_000)
            if not reduce_motion:
                page.wait_for_timeout(2_000)
            clip = (
                {"x": 0, "y": 160, "width": width, "height": 480}
                if locale == "de"
                else None
            )
            page.screenshot(path=str(OUTPUT / filename), clip=clip)
            context.close()
        browser.close()
    if errors:
        raise RuntimeError(f"Browser reported page errors: {errors}")
    print(
        {
            "captures": [
                {
                    "filename": filename,
                    "viewport_css_px": {"width": width, "height": height},
                    "device_pixel_ratio": 1,
                    "locale": locale,
                    "text_scale": scale,
                    "ownership": ownership,
                    "theme": "light Material 3",
                    "reduced_motion": reduce_motion,
                }
                for filename, width, height, locale, scale, ownership, reduce_motion in captures
            ]
        }
    )


if __name__ == "__main__":
    main()
