from io import BytesIO
from pathlib import Path
import subprocess
import tempfile
import time

from PIL import Image, ImageStat
from playwright.sync_api import sync_playwright

ROOT = Path(__file__).resolve().parents[2]
OUTPUT_DIR = ROOT / "docs/qa/voice_batch_separator_hint"
SCREENSHOT = OUTPUT_DIR / "voice-batch-separator-hint-de-320x640-1x-light.png"
PREVIEW = OUTPUT_DIR / "voice-batch-separator-hint-reveal-de-320x640-1x-light.webm"
URL = "http://127.0.0.1:8875/?theme=light"
OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

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
    page.goto(URL, wait_until="load", timeout=120_000)
    page.locator("flt-semantics-placeholder").wait_for(timeout=120_000)
    deadline = time.monotonic() + 120
    while True:
        rendered = Image.open(BytesIO(page.screenshot())).convert("RGB")
        if max(ImageStat.Stat(rendered).stddev) >= 1:
            break
        if time.monotonic() >= deadline:
            raise RuntimeError("Flutter Web did not render within 120 seconds")
        time.sleep(1)

    page.locator("flt-semantics-placeholder").focus()
    page.keyboard.press("Enter")
    page.wait_for_function("document.body.innerText.includes('Tabulator')")

    # Select the custom separator from the production dropdown.
    page.mouse.click(140, 128)
    page.wait_for_timeout(300)
    page.mouse.click(130, 318)
    page.wait_for_timeout(500)

    # The custom field is inserted beneath the separator dropdown. Keep it
    # empty so the localized hint remains visible, then capture it focused.
    page.mouse.click(150, 165)
    page.wait_for_timeout(250)
    active = page.evaluate(
        "document.activeElement && document.activeElement.tagName.toLowerCase()"
    )
    if active not in ("input", "textarea"):
        raise RuntimeError(f"Custom separator field did not receive focus: {active}")

    screenshot = page.screenshot()
    image = Image.open(BytesIO(screenshot)).convert("RGB")
    if image.size != (320, 640) or max(ImageStat.Stat(image).stddev) < 1:
        raise RuntimeError("Flutter Web produced an invalid or blank capture")
    SCREENSHOT.write_bytes(screenshot)

    frame_rate = 10
    preview_duration = 9
    with tempfile.TemporaryDirectory(
        prefix="voice-separator-reveal-frames-", dir=OUTPUT_DIR
    ) as frame_directory:
        frame_directory = Path(frame_directory)
        frame_deadline = time.monotonic() + preview_duration
        frame_number = 0
        next_frame = time.monotonic()
        while time.monotonic() < frame_deadline:
            (frame_directory / f"frame-{frame_number:04d}.png").write_bytes(
                page.screenshot()
            )
            frame_number += 1
            next_frame += 1 / frame_rate
            page.wait_for_timeout(
                max(0, round((next_frame - time.monotonic()) * 1000))
            )
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

    print(
        {
            "screenshot": str(SCREENSHOT.relative_to(ROOT)),
            "preview": str(PREVIEW.relative_to(ROOT)),
            "viewport_css_px": page.viewport_size,
            "device_pixel_ratio": page.evaluate("devicePixelRatio"),
            "locale": "de_DE",
            "theme": "light",
            "text_scale": 1,
            "focus": "empty custom separator TextField",
            "keyboard": "closed (headless desktop Chromium)",
            "active_element": active,
            "preview_duration_seconds": preview_duration,
            "preview_frames_per_second": frame_rate,
            "page_errors": errors,
        }
    )
    browser.close()

if errors:
    raise RuntimeError(f"Browser reported runtime errors: {errors}")
