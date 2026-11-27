from pathlib import Path
import subprocess
import tempfile
import time

from playwright.sync_api import sync_playwright

from capture_render_readiness import (
    capture_video_frames,
    navigate_and_wait_for_flutter_render,
    write_video_frame_manifest,
)

ROOT = Path(__file__).resolve().parents[2]
OUTPUT = ROOT / "docs/qa/vertical_topic_metadata_bounds"
CAPTURE = OUTPUT / "topic-metadata-fr-320x640-1x-light.png"
SCREENSHOT_URL = "http://127.0.0.1:8878/?theme=light&scale=1"
PREVIEW_URL = "http://127.0.0.1:8878/?theme=light&scale=2"
OUTPUT.mkdir(parents=True, exist_ok=True)

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
    )
    video_page = video_context.new_page()
    video_page.on("pageerror", lambda error: errors.append(str(error)))
    navigate_and_wait_for_flutter_render(
        video_page, PREVIEW_URL, (320, 640), "Topic"
    )
    await_motion_seconds = 15
    frame_rate = 10
    with tempfile.TemporaryDirectory(
        prefix="topic-metadata-video-", dir=OUTPUT
    ) as temporary_frames:
        frames = Path(temporary_frames)
        capture_started_at = time.monotonic()
        capture_deadline = capture_started_at + await_motion_seconds
        frame_times = capture_video_frames(
            video_page, frames, capture_started_at, capture_deadline, frame_rate
        )
        manifest = write_video_frame_manifest(
            frames, frame_times, capture_started_at, capture_deadline
        )
        video_page.close()
        video_context.close()
        preview = OUTPUT / "topic-metadata-reveal-fr-320x640-1x-light.webm"
        subprocess.run(
            [
                "ffmpeg",
                "-y",
                "-loglevel",
                "error",
                "-f",
                "concat",
                "-safe",
                "0",
                "-i",
                str(manifest),
                "-t",
                str(await_motion_seconds),
                "-vsync",
                "vfr",
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
