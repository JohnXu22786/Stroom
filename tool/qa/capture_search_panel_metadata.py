from pathlib import Path
import subprocess
import tempfile

from playwright.sync_api import sync_playwright


ROOT = Path(__file__).resolve().parents[2]
OUTPUT = ROOT / "docs/qa/bounded_search_metadata"
URL = "http://127.0.0.1:8878"
OUTPUT.mkdir(parents=True, exist_ok=True)


def capture(page, locale: str, scale: float, theme: str) -> None:
    page.goto(
        f"{URL}/?locale={locale}&scale={scale}&theme={theme}",
        wait_until="load",
    )
    page.get_by_role("textbox").fill("Demo")
    page.wait_for_timeout(1_300)


def main() -> None:
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
            reduced_motion="no-preference",
        )
        page = context.new_page()
        page.on("pageerror", lambda error: errors.append(str(error)))
        capture(page, "zh-CN", 1, "light")
        if page.evaluate("devicePixelRatio") != 1:
            raise RuntimeError("Expected a 1x browser device scale factor")
        page.screenshot(
            path=str(OUTPUT / "search-metadata-zh-320x640-scale1-light.png")
        )
        browser.close()

    with tempfile.TemporaryDirectory(prefix="stroom-search-metadata-") as frame_dir:
        frames = Path(frame_dir)
        with sync_playwright() as playwright:
            browser = playwright.chromium.launch(
                headless=True,
                executable_path="/usr/bin/chromium",
                args=["--no-sandbox", "--disable-dev-shm-usage"],
            )
            context = browser.new_context(
                viewport={"width": 320, "height": 640},
                device_scale_factor=1,
                reduced_motion="no-preference",
            )
            page = context.new_page()
            page.on("pageerror", lambda error: errors.append(str(error)))
            capture(page, "zh-CN", 2.5, "light")
            for frame in range(40):
                page.screenshot(path=str(frames / f"frame-{frame:03d}.png"))
                page.wait_for_timeout(250)
            browser.close()

        if errors:
            raise RuntimeError(f"Browser reported page errors: {errors}")
        subprocess.run(
            [
                "ffmpeg",
                "-hide_banner",
                "-loglevel",
                "error",
                "-y",
                "-framerate",
                "4",
                "-i",
                str(frames / "frame-%03d.png"),
                "-c:v",
                "libvpx-vp9",
                "-b:v",
                "1M",
                "-pix_fmt",
                "yuv420p",
                "-vf",
                "crop=320:230:0:350",
                str(OUTPUT / "search-metadata-reveal-320x640-scale2_5.webm"),
            ],
            check=True,
        )

    print(
        {
            "viewport_css_px": {"width": 320, "height": 640},
            "device_pixel_ratio": 1,
            "screenshot_locale": "zh-CN",
            "preview_locale": "zh-CN",
            "theme": "blue-seeded light",
            "screenshot_text_scale": 1,
            "preview_text_scale": 2.5,
            "focus": "search field contains Demo and remains focused",
            "keyboard": "no software keyboard in desktop Chromium",
            "fixture": "local synthetic conversation with two messages",
            "page_errors": errors,
        }
    )


if __name__ == "__main__":
    main()
