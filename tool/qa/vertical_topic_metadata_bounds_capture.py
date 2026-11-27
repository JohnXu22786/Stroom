from pathlib import Path
import shutil
import subprocess
import time

from playwright.sync_api import sync_playwright

from capture_render_readiness import (
    navigate_and_wait_for_flutter_render,
    video_preview_timing,
)

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
    navigate_and_wait_for_flutter_render(
        screenshot_page, SCREENSHOT_URL, (320, 640), "Topic"
    )
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
    recording_started = time.monotonic()
    video_page.on("pageerror", lambda error: errors.append(str(error)))
    navigate_and_wait_for_flutter_render(
        video_page, PREVIEW_URL, (320, 640), "Topic"
    )
    motion_started_at = time.monotonic()
    await_motion_seconds = 15
    readiness_offset_seconds, recording_wait_seconds = video_preview_timing(
        recording_started, motion_started_at, await_motion_seconds
    )
    video_page.wait_for_timeout(round(recording_wait_seconds * 1_000))
    video_path = video_page.video.path()
    video_page.close()
    video_context.close()
    preview = OUTPUT / "topic-metadata-reveal-fr-320x640-1x-light.webm"
    subprocess.run(
        [
            "ffmpeg",
            "-y",
            "-ss",
            f"{readiness_offset_seconds:.3f}",
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
