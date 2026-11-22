from pathlib import Path
import subprocess
import tempfile

from playwright.sync_api import sync_playwright


ROOT = Path(__file__).resolve().parents[2]
OUTPUT = ROOT / "docs/qa/browser_cookie_path"
URL = "http://127.0.0.1:8879"
OUTPUT.mkdir(parents=True, exist_ok=True)

errors = []
with tempfile.TemporaryDirectory(prefix="stroom-cookie-path-") as frame_dir:
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
        page.goto(URL, wait_until="load")
        # The web build paints on CanvasKit; wait for its first complete frame.
        page.wait_for_timeout(10_000)
        if page.evaluate("devicePixelRatio") != 1:
            raise RuntimeError("Expected a 1x browser device scale factor")
        page.screenshot(
            path=str(OUTPUT / "cookie-path-en-320x640-1x-light.png")
        )
        for frame in range(160):
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
            str(OUTPUT / "cookie-path-reveal-320x640-1x-light.webm"),
        ],
        check=True,
    )

print(
    {
        "viewport_css_px": {"width": 320, "height": 640},
        "device_pixel_ratio": 1,
        "locale": "en-US",
        "theme": "blue-seeded light",
        "text_scale": 1,
        "focus": "no control focused",
        "keyboard": "none; no editable input is present",
        "page_errors": errors,
    }
)
