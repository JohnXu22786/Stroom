from pathlib import Path
import shutil
import subprocess
import tempfile

from playwright.sync_api import sync_playwright

ROOT = Path(__file__).resolve().parents[2]
OUTPUT = ROOT / "docs/images/ui-guidelines/search-highlight-reveal"
URL = "http://127.0.0.1:8765"
FRAME_COUNT = 100
FRAME_WAIT_MS = 50

OUTPUT.mkdir(parents=True, exist_ok=True)
with tempfile.TemporaryDirectory(prefix="stroom-search-reveal-") as frame_dir:
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
        errors = []
        page.on("pageerror", lambda error: errors.append(str(error)))
        page.goto(URL, wait_until="load", timeout=120_000)
        # Give the release build time to finish its first layout and localization.
        page.wait_for_timeout(5_000)
        field = page.locator("input").first
        field.click(position={"x": 100, "y": 10})
        page.keyboard.type("needle")
        page.wait_for_function(
            "document.querySelector('input').value === 'needle'", timeout=10_000
        )
        field.evaluate("element => element.blur()")
        page.wait_for_timeout(250)
        page.screenshot(path=str(OUTPUT / "search-highlight-reveal-320x640.png"))
        for frame in range(FRAME_COUNT):
            page.screenshot(path=str(frames / f"frame-{frame:03d}.png"))
            page.wait_for_timeout(FRAME_WAIT_MS)
        if field.input_value() != "needle":
            raise RuntimeError("Search query was not retained during capture.")
        if errors:
            raise RuntimeError(f"Browser reported runtime errors: {errors}")
        print(
            {
                "browser": playwright.chromium.name,
                "viewport_css_px": page.viewport_size,
                "device_pixel_ratio": page.evaluate("devicePixelRatio"),
                "locale": "zh_CN",
                "theme": "light",
                "text_scale": 1.0,
                "query": field.input_value(),
                "frames": FRAME_COUNT,
                "page_errors": errors,
            }
        )
        browser.close()
    subprocess.run(
        [
            "ffmpeg",
            "-hide_banner",
            "-loglevel",
            "error",
            "-y",
            "-framerate",
            "12",
            "-i",
            str(frames / "frame-%03d.png"),
            "-c:v",
            "libvpx-vp9",
            "-b:v",
            "1M",
            "-pix_fmt",
            "yuv420p",
            str(OUTPUT / "search-highlight-reveal-motion.webm"),
        ],
        check=True,
    )
