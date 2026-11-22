from pathlib import Path
import shutil
import subprocess

from playwright.sync_api import sync_playwright

ROOT = Path(__file__).resolve().parents[2]
OUTPUT = ROOT / "docs/qa/vertical_topic_metadata_bounds"
CAPTURE = OUTPUT / "topic-metadata-fr-320x640-1x-light.png"
VIDEO_DIR = OUTPUT / "video"
SCREENSHOT_URL = "http://127.0.0.1:8878/?theme=light&scale=1"
PREVIEW_URL = "http://127.0.0.1:8878/?theme=light&scale=2"
OUTPUT.mkdir(parents=True, exist_ok=True)
VIDEO_DIR.mkdir(parents=True, exist_ok=True)

with sync_playwright() as playwright:
    browser = playwright.chromium.launch(
        headless=True,
        executable_path="/usr/bin/chromium",
        args=["--no-sandbox", "--disable-dev-shm-usage"],
    )
    errors = []
    screenshot_context = browser.new_context(
        viewport={"width": 320, "height": 640},
        device_scale_factor=1,
        reduced_motion="reduce",
    )
    screenshot_page = screenshot_context.new_page()
    screenshot_page.on("pageerror", lambda error: errors.append(str(error)))
    screenshot_page.goto(SCREENSHOT_URL, wait_until="load")
    screenshot_page.wait_for_timeout(8_000)
    screenshot_page.screenshot(path=str(CAPTURE))
    screenshot_page.close()
    screenshot_context.close()

    video_context = browser.new_context(
        viewport={"width": 320, "height": 640},
        device_scale_factor=1,
        record_video_dir=str(VIDEO_DIR),
        record_video_size={"width": 320, "height": 640},
    )
    video_page = video_context.new_page()
    video_page.on("pageerror", lambda error: errors.append(str(error)))
    video_page.goto(PREVIEW_URL, wait_until="load")
    video_page.wait_for_timeout(8_000)
    await_motion_seconds = 15
    video_page.wait_for_timeout(await_motion_seconds * 1_000)
    video_path = video_page.video.path()
    video_page.close()
    video_context.close()
    preview = OUTPUT / "topic-metadata-reveal-fr-320x640-1x-light.webm"
    subprocess.run(
        [
            "ffmpeg",
            "-y",
            "-ss",
            "15",
            "-i",
            video_path,
            "-t",
            str(await_motion_seconds),
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
    print(
        {
            "screenshot": str(CAPTURE.relative_to(ROOT)),
            "preview": str(preview.relative_to(ROOT)),
            "viewport_css_px": {"width": 320, "height": 640},
            "device_pixel_ratio": 1,
            "locale": "fr_FR",
            "theme": "light",
            "text_scale": 1,
            "preview_text_scale": 2,
            "topic": "synthetic local topic with one message",
            "page_errors": errors,
        }
    )
    browser.close()

if errors:
    raise RuntimeError(f"Browser reported runtime errors: {errors}")
