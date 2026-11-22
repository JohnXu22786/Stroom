from pathlib import Path
import shutil
import subprocess
import time

from playwright.sync_api import sync_playwright

ROOT = Path(__file__).resolve().parents[2]
CAPTURE = ROOT / "docs/qa/image_editor_tool_bounds/image-editor-fr-320x640-1x-light.png"
VIDEO_DIR = ROOT / "docs/qa/image_editor_tool_bounds/video"
BASE_URL = "http://127.0.0.1:8874/?theme=light"
CAPTURE.parent.mkdir(parents=True, exist_ok=True)
VIDEO_DIR.mkdir(parents=True, exist_ok=True)

with sync_playwright() as playwright:
    browser = playwright.chromium.launch(
        headless=True,
        executable_path="/usr/bin/chromium",
        args=["--no-sandbox", "--disable-dev-shm-usage"],
    )
    context = browser.new_context(
        viewport={"width": 320, "height": 640},
        device_scale_factor=1,
        record_video_dir=str(VIDEO_DIR),
        record_video_size={"width": 320, "height": 640},
    )
    page = context.new_page()
    recording_started = time.monotonic()
    errors = []
    page.on("pageerror", lambda error: errors.append(str(error)))
    page.goto(BASE_URL, wait_until="load")
    page.wait_for_timeout(2_000)
    page.screenshot(path=str(CAPTURE))
    ready_offset = time.monotonic() - recording_started
    print(
        {
            "output": str(CAPTURE.relative_to(ROOT)),
            "viewport_css_px": page.viewport_size,
            "device_pixel_ratio": page.evaluate("devicePixelRatio"),
            "locale": "fr_FR",
            "theme": "light",
            "text_scale": 1,
            "focus": "none",
            "keyboard": "closed",
            "image": "generated synthetic local fixture",
            "page_errors": errors,
        }
    )
    page.wait_for_timeout(14_000)
    video_path = page.video.path()
    page.close()
    context.close()
    preview = CAPTURE.parent / "image-editor-label-reveal-fr-320x640-1x.webm"
    subprocess.run(
        [
            "ffmpeg",
            "-y",
            "-ss",
            str(ready_offset),
            "-i",
            video_path,
            "-t",
            "14",
            "-an",
            "-c:v",
            "libvpx-vp9",
            "-crf",
            "34",
            "-b:v",
            "0",
            str(preview),
        ],
        check=True,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )
    shutil.rmtree(VIDEO_DIR)
    print({"motion_preview": str(preview.relative_to(ROOT))})
    browser.close()

if errors:
    raise RuntimeError(f"Browser reported runtime errors: {errors}")
