import os
from pathlib import Path
import subprocess
import tempfile

from playwright.sync_api import sync_playwright


ROOT = Path(__file__).resolve().parents[2]
OUTPUT = ROOT / "docs/ui-constrained-text-qa/vertical-background-service-buttons"
URL = "http://127.0.0.1:8892"
TEMP_ROOT = Path(os.environ.get("TMPDIR") or tempfile.gettempdir())
OUTPUT.mkdir(parents=True, exist_ok=True)
TEMP_ROOT.mkdir(parents=True, exist_ok=True)


def open_fixture(page, theme: str = "light") -> None:
    page.goto(
        f"{URL}/?locale=fr-FR&state=running&theme={theme}",
        wait_until="load",
    )
    page.wait_for_timeout(1_500)


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
            reduced_motion="reduce",
        )
        page = context.new_page()
        page.on("pageerror", lambda error: errors.append(str(error)))
        open_fixture(page)
        page.screenshot(
            path=str(OUTPUT / "service-running-fr-320x640-scale1-light.png")
        )
        open_fixture(page, "dark")
        page.screenshot(
            path=str(OUTPUT / "service-running-fr-320x640-scale1-dark.png")
        )
        browser.close()

    with tempfile.TemporaryDirectory(
        prefix="stroom-vertical-service-buttons-",
        dir=TEMP_ROOT,
    ) as frame_dir:
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
            open_fixture(page)
            for frame in range(32):
                page.screenshot(path=str(frames / f"frame-{frame:03d}.png"))
                page.wait_for_timeout(250)
            browser.close()
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
                "crop=320:320:0:0",
                str(OUTPUT / "service-stop-label-reveal-fr-320x640.webm"),
            ],
            check=True,
        )

    if errors:
        raise RuntimeError(f"Browser reported runtime errors: {errors}")
    print(
        {
            "viewport_css_px": {"width": 320, "height": 640},
            "device_pixel_ratio": 1,
            "locale": "fr-FR",
            "screenshots": "blue-seeded light and dark",
            "preview_theme": "blue-seeded light",
            "text_scale": 1,
            "focus": "none",
            "keyboard": "closed; no software keyboard in desktop Chromium",
            "state": "service running; no operation in progress",
            "fixture": "production BackgroundServiceControlButtons with no-op callbacks",
            "page_errors": errors,
        }
    )


if __name__ == "__main__":
    main()
