from pathlib import Path
import subprocess
import tempfile

from playwright.sync_api import sync_playwright


ROOT = Path(__file__).resolve().parents[2]
OUTPUT = ROOT / "docs/ui-constrained-text-qa/navigation-labels"
URL = "http://127.0.0.1:8877"
OUTPUT.mkdir(parents=True, exist_ok=True)


def open_browser(playwright):
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
    return browser, context, context.new_page()


def main():
    errors = []
    with sync_playwright() as playwright:
        browser, context, page = open_browser(playwright)
        page.on("pageerror", lambda error: errors.append(str(error)))
        with page.expect_console_message(
            predicate=lambda message: "Starting application from main method"
            in message.text,
            timeout=180_000,
        ):
            page.goto(
                f"{URL}/?locale=de&scale=1&theme=light&motion=true",
                wait_until="load",
            )
        page.wait_for_timeout(1_300)
        if page.evaluate("devicePixelRatio") != 1:
            raise RuntimeError("Expected a 1x browser device scale factor")
        page.screenshot(path=str(OUTPUT / "portrait-de-320x640-scale1_0.png"))
        context.close()
        browser.close()

    with tempfile.TemporaryDirectory(prefix="stroom-navigation-labels-") as frame_dir:
        frames = Path(frame_dir)
        with sync_playwright() as playwright:
            browser, _, page = open_browser(playwright)
            page.on("pageerror", lambda error: errors.append(str(error)))
            with page.expect_console_message(
                predicate=lambda message: "Starting application from main method"
                in message.text,
                timeout=180_000,
            ):
                page.goto(
                    f"{URL}/?locale=pt-BR&scale=1&theme=light&motion=true",
                    wait_until="load",
                )
            page.wait_for_timeout(1_300)
            for frame in range(32):
                page.screenshot(path=str(frames / f"frame-{frame:03d}.png"))
                page.wait_for_timeout(250)
            browser.close()

        if errors:
            raise RuntimeError(f"Browser reported runtime errors: {errors}")
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
                str(OUTPUT / "navigation-label-reveal-pt-br-320x640.webm"),
            ],
            check=True,
        )
    print(
        {
            "viewport_css_px": {"width": 320, "height": 640},
            "device_pixel_ratio": 1,
            "screenshot_locale": "de",
            "preview_locale": "pt_BR",
            "theme": "light",
            "text_scale": 1,
            "label": "Configurações",
            "page_errors": errors,
            "screenshots": ["portrait-de-320x640-scale1_0.png"],
            "preview": "navigation-label-reveal-pt-br-320x640.webm",
        }
    )


if __name__ == "__main__":
    main()
