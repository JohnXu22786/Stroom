from pathlib import Path
import subprocess
import tempfile

from playwright.sync_api import sync_playwright


ROOT = Path(__file__).resolve().parents[2]
OUTPUT = ROOT / "docs/ui-constrained-text-qa/vertical-flow-subtask-status"
URL = "http://127.0.0.1:8880"
OUTPUT.mkdir(parents=True, exist_ok=True)

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
    page.goto(
        f"{URL}/?locale=de-DE&scale=1&theme=light&motion=false",
        wait_until="load",
    )
    page.wait_for_timeout(8_000)
    page.screenshot(
        path=str(OUTPUT / "flow-subtask-status-de-320x640-scale1-light.png")
    )
    page.goto(
        f"{URL}/?locale=de-DE&scale=1&theme=dark&motion=false",
        wait_until="load",
    )
    page.wait_for_timeout(2_000)
    page.screenshot(
        path=str(OUTPUT / "flow-subtask-status-de-320x640-scale1-dark.png")
    )
    if errors:
        raise RuntimeError(f"Browser reported runtime errors: {errors}")
    browser.close()

with tempfile.TemporaryDirectory(prefix="stroom-flow-subtask-status-") as frame_dir:
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
        page.goto(
            f"{URL}/?locale=ar-SA&scale=1.5&theme=light&motion=true",
            wait_until="load",
        )
        page.wait_for_timeout(8_000)
        for frame in range(36):
            page.screenshot(path=str(frames / f"frame-{frame:03d}.png"))
            page.wait_for_timeout(250)
        if errors:
            raise RuntimeError(f"Browser reported runtime errors: {errors}")
        print(
            {
                "viewport_css_px": page.viewport_size,
                "device_pixel_ratio": page.evaluate("devicePixelRatio"),
                "locale": "ar_SA",
                "theme": "light",
                "text_scale": 1.5,
                "preview_frames": 36,
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
            "4",
            "-i",
            str(frames / "frame-%03d.png"),
            "-c:v",
            "libvpx-vp9",
            "-b:v",
            "1M",
            "-pix_fmt",
            "yuv420p",
            str(OUTPUT / "flow-subtask-status-motion-320x640.webm"),
        ],
        check=True,
    )
