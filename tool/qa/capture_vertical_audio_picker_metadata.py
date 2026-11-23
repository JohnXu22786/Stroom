from pathlib import Path
import subprocess

from playwright.sync_api import sync_playwright


ROOT = Path(__file__).resolve().parents[2]
WEB_BUILD = Path(
    "/workspace/.cloud-profile-state/vertical_audio_picker_metadata/web-build"
)
OUTPUT = ROOT / "docs/ui-constrained-text-qa/vertical-audio-picker-metadata"
URL = "http://127.0.0.1:8894"
OUTPUT.mkdir(parents=True, exist_ok=True)

server = subprocess.Popen(
    ["python3", "-m", "http.server", "8894", "--bind", "127.0.0.1", "--directory", str(WEB_BUILD)],
    stdout=subprocess.DEVNULL,
    stderr=subprocess.DEVNULL,
)

try:
    with sync_playwright() as playwright:
        browser = playwright.chromium.launch(
            headless=True,
            executable_path="/usr/bin/chromium",
            args=["--no-sandbox", "--disable-dev-shm-usage"],
        )
        for label, width, height in (("narrow", 320, 640), ("wide", 1200, 800)):
            context = browser.new_context(
                viewport={"width": width, "height": height},
                device_scale_factor=1,
                reduced_motion="reduce",
            )
            page = context.new_page()
            errors = []
            page.on("pageerror", lambda error: errors.append(str(error)))
            page.goto(f"{URL}/?locale=de-DE", wait_until="load")
            page.wait_for_timeout(3_000)
            # Flutter Web does not expose the semantics tree in this capture,
            # so open the centered fixture trigger by its known layout position.
            page.mouse.click(width / 2, height / 2)
            page.wait_for_timeout(500)
            page.screenshot(
                path=str(
                    OUTPUT
                    / f"audio-picker-metadata-{label}-de-DE-320x640-scale1-light.png"
                    if label == "narrow"
                    else OUTPUT / "audio-picker-metadata-wide-de-DE-scale1-light.png"
                )
            )
            if errors:
                raise RuntimeError(f"Browser reported runtime errors: {errors}")
            context.close()
        browser.close()
finally:
    server.terminate()
    server.wait(timeout=10)
