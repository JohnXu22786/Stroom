from pathlib import Path
from playwright.sync_api import sync_playwright

ROOT = Path(__file__).resolve().parents[2]
OUTPUT = ROOT / "docs/qa/tts_speech_content"
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
        for locale, width, scale, scroll, filename in (
            (
                "ar",
                320,
                3,
                120,
                "speech-content-ar-320x640-scale3-light.png",
            ),
            (
                "pt-BR",
                320,
                3,
                120,
                "speech-content-pt-BR-320x640-scale3-light.png",
            ),
            (
                "pt-BR",
                600,
                1,
                0,
                "speech-content-pt-BR-600x640-scale1-light.png",
            ),
        ):
            page = context.new_page()
            page.set_viewport_size({"width": width, "height": 640})
            page.on("pageerror", lambda error: errors.append(str(error)))
            page.goto(
                f"{URL}/?locale={locale}&scale={scale}",
                wait_until="load",
                timeout=180_000,
            )
            page.wait_for_timeout(10_000)
            if page.evaluate("devicePixelRatio") != 1:
                raise RuntimeError("Expected device scale factor 1")
            if scroll:
                page.mouse.move(160, 500)
                page.mouse.wheel(0, scroll)
                page.wait_for_timeout(500)
            page.screenshot(path=str(OUTPUT / filename))
            page.close()
        context.close()
        browser.close()
    if errors:
        raise RuntimeError(f"Browser reported page errors: {errors}")
    print(
        {
            "viewports_css_px": {
                "320x640": ["ar/3x", "pt-BR/3x"],
                "600x640": ["pt-BR/1x"],
            },
            "device_pixel_ratio": 1,
            "locales_and_scales": {"ar": [3], "pt-BR": [1, 3]},
            "theme": "light",
            "state": "new TTS synthesis form; provider fixture loaded; no field focused; 3× captures scrolled 120 logical pixels",
            "reduced_motion": True,
        }
    )


if __name__ == "__main__":
    main()
