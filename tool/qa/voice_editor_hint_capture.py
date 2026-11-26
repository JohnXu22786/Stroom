from io import BytesIO
from pathlib import Path
import subprocess
import tempfile
import time

from PIL import Image, ImageStat
from playwright.sync_api import sync_playwright

ROOT = Path(__file__).resolve().parents[2]
OUTPUT_DIR = ROOT / "docs/qa/voice_editor_input_hints"
NARROW = OUTPUT_DIR / "voice-editor-hints-es-320x640-1x-light.png"
FITTING = OUTPUT_DIR / "voice-editor-hints-es-800x640-1x-light.png"
PREVIEW = OUTPUT_DIR / "voice-editor-hints-reveal-es-320x640-1x-light.webm"
URL = "http://127.0.0.1:8876/"
OUTPUT_DIR.mkdir(parents=True, exist_ok=True)


def wait_for_render(page, expected_size):
    page.goto(URL, wait_until="load", timeout=120_000)
    page.locator("flt-semantics-placeholder").wait_for(timeout=120_000)
    deadline = time.monotonic() + 120
    while True:
        rendered = Image.open(BytesIO(page.screenshot())).convert("RGB")
        if rendered.size == expected_size and max(ImageStat.Stat(rendered).stddev) >= 1:
            return
        if time.monotonic() >= deadline:
            raise RuntimeError("Flutter Web did not render within 120 seconds")
        time.sleep(1)


with sync_playwright() as playwright:
    browser = playwright.chromium.launch(
        headless=True,
        executable_path="/usr/bin/chromium",
        args=["--no-sandbox", "--disable-dev-shm-usage"],
    )
    page = browser.new_page(
        viewport={"width": 320, "height": 640},
        device_scale_factor=1,
    )
    errors = []
    page.on("pageerror", lambda error: errors.append(str(error)))
    wait_for_render(page, (320, 640))
    page.wait_for_timeout(350)
    NARROW.write_bytes(page.screenshot())

    frame_rate = 10
    preview_duration = 9
    with tempfile.TemporaryDirectory(
        prefix="voice-editor-hint-frames-", dir=OUTPUT_DIR
    ) as frame_directory:
        frame_directory = Path(frame_directory)
        deadline = time.monotonic() + preview_duration
        frame_number = 0
        next_frame = time.monotonic()
        while time.monotonic() < deadline:
            (frame_directory / f"frame-{frame_number:04d}.png").write_bytes(
                page.screenshot()
            )
            frame_number += 1
            next_frame += 1 / frame_rate
            page.wait_for_timeout(max(0, round((next_frame - time.monotonic()) * 1000)))
        subprocess.run(
            [
                "ffmpeg",
                "-y",
                "-loglevel",
                "error",
                "-framerate",
                str(frame_rate),
                "-i",
                str(frame_directory / "frame-%04d.png"),
                "-c:v",
                "libvpx-vp9",
                "-deadline",
                "good",
                "-cpu-used",
                "4",
                "-b:v",
                "0",
                "-crf",
                "32",
                "-pix_fmt",
                "yuv420p",
                "-an",
                str(PREVIEW),
            ],
            check=True,
        )

    page.set_viewport_size({"width": 800, "height": 640})
    page.wait_for_timeout(250)
    FITTING.write_bytes(page.screenshot())
    browser.close()

print(
    {
        "narrow_screenshot": str(NARROW.relative_to(ROOT)),
        "fitting_screenshot": str(FITTING.relative_to(ROOT)),
        "motion_preview": str(PREVIEW.relative_to(ROOT)),
        "narrow_viewport_css_px": {"width": 320, "height": 640},
        "fitting_viewport_css_px": {"width": 800, "height": 640},
        "device_pixel_ratio": 1,
        "locale": "es_ES",
        "theme": "light",
        "text_scale": 1,
        "preview_duration_seconds": preview_duration,
        "preview_frames_per_second": frame_rate,
        "page_errors": errors,
    }
)
if errors:
    raise RuntimeError(f"Browser reported runtime errors: {errors}")
