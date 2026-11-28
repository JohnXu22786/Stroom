from pathlib import Path
from io import BytesIO
import subprocess
import tempfile

from PIL import Image
from playwright.sync_api import sync_playwright

ROOT = Path(__file__).resolve().parents[2]
OUTPUT = ROOT / "docs/qa/recording_actions"
BASE_URL = "http://127.0.0.1:8874/"
CAPTURES = (
    (
        "recording",
        320,
        "en",
        1,
        OUTPUT / "recording-320x640-1x-en-light.png",
    ),
    (
        "paused",
        320,
        "en",
        1,
        OUTPUT / "paused-320x640-1x-en-light.png",
    ),
    (
        "completed",
        320,
        "en",
        1,
        OUTPUT / "completed-320x640-1x-en-light.png",
    ),
    (
        "recording",
        400,
        "en",
        1,
        OUTPUT / "recording-400x640-1x-en-light.png",
    ),
    (
        "recording",
        320,
        "fr",
        3,
        OUTPUT / "recording-320x640-3x-fr-light.png",
    ),
)

OUTPUT.mkdir(parents=True, exist_ok=True)
page_errors = []

with sync_playwright() as playwright:
    browser = playwright.chromium.launch(
        headless=True,
        executable_path="/usr/bin/chromium",
        args=["--no-sandbox", "--disable-dev-shm-usage"],
    )
    context = browser.new_context(
        viewport={"width": 320, "height": 640},
        device_scale_factor=1,
    )
    page = context.new_page()
    page.on("pageerror", lambda error: page_errors.append(str(error)))

    for state, width, locale, scale, output in CAPTURES:
        page.set_viewport_size({"width": width, "height": 640})
        focus = "actions" if scale > 1 else "page"
        page.goto(
            f"{BASE_URL}?state={state}&locale={locale}&scale={scale}&focus={focus}",
            wait_until="load",
        )
        page.evaluate("document.fonts.ready")
        screenshot = None
        for _ in range(40):
            screenshot = page.screenshot()
            image = Image.open(BytesIO(screenshot)).convert("RGB")
            if len(image.getcolors(width * 640) or []) > 10:
                break
            page.wait_for_timeout(500)
        else:
            raise RuntimeError(f"Flutter did not render the {state} state")
        output.write_bytes(screenshot)
        print(
            {
                "output": str(output.relative_to(ROOT)),
                "state": state,
                "viewport_css_px": page.viewport_size,
                "device_pixel_ratio": page.evaluate("devicePixelRatio"),
                "locale": locale,
                "theme": "light",
                "text_scale": scale,
                "focus": focus,
                "keyboard": "closed",
                "page_errors": page_errors,
            }
        )

    browser.close()

if page_errors:
    raise RuntimeError(f"Chromium reported page errors: {page_errors}")

with tempfile.TemporaryDirectory(prefix="stroom-recording-actions-") as frame_dir:
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
        page.on("pageerror", lambda error: page_errors.append(str(error)))
        page.goto(
            f"{BASE_URL}?state=recording&locale=fr&scale=3&focus=actions",
            wait_until="load",
        )
        page.evaluate("document.fonts.ready")
        for _ in range(40):
            screenshot = page.screenshot()
            image = Image.open(BytesIO(screenshot)).convert("RGB")
            if len(image.getcolors(320 * 640) or []) > 10:
                break
            page.wait_for_timeout(250)
        else:
            raise RuntimeError("Flutter did not render the motion preview")
        for frame in range(96):
            page.screenshot(path=str(frames / f"frame-{frame:03d}.png"))
            page.wait_for_timeout(250)
        browser.close()

    if page_errors:
        raise RuntimeError(f"Chromium reported page errors: {page_errors}")
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
            "crop=320:240:0:200",
            str(OUTPUT / "recording-actions-reveal-fr-320x640-scale3.webm"),
        ],
        check=True,
    )
