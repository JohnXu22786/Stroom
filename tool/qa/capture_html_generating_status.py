import argparse
import socket
import subprocess
import time
from io import BytesIO
from pathlib import Path

from PIL import Image, ImageStat
from playwright.sync_api import sync_playwright


ROOT = Path(__file__).resolve().parents[2]
OUTPUT = ROOT / "docs/qa/html_generating_status"
WEB = Path("/tmp/stroom-html-generating-status-web")
OUTPUT.mkdir(parents=True, exist_ok=True)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--skip-build", action="store_true")
    args = parser.parse_args()
    if not args.skip_build:
        subprocess.run(
            [
                "flutter",
                "build",
                "web",
                "--release",
                "--no-pub",
                "--target",
                "tool/qa/html_generating_status_capture.dart",
                "--output",
                str(WEB),
                "--no-wasm-dry-run",
            ],
            cwd=ROOT,
            check=True,
        )
    with socket.socket() as listener:
        listener.bind(("127.0.0.1", 0))
        port = listener.getsockname()[1]
    server = subprocess.Popen(
        ["python3", "-m", "http.server", str(port), "--directory", str(WEB)],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )
    errors = []
    try:
        time.sleep(1)
        with sync_playwright() as playwright:
            browser = playwright.chromium.launch(
                headless=True,
                executable_path="/usr/bin/chromium",
                args=["--no-sandbox", "--disable-dev-shm-usage"],
            )
            url = f"http://127.0.0.1:{port}/"
            cases = [
                (
                    "narrow-de-320x640-scale1_8-light.png",
                    {"width": 320, "height": 640},
                    "?state=overflow&locale=de-DE&scale=1.8",
                ),
                (
                    "fitting-en-1000x800-scale1-light.png",
                    {"width": 1000, "height": 800},
                    "?state=fitting&locale=en&scale=1",
                ),
            ]
            for filename, viewport, state in cases:
                page = browser.new_page(
                    viewport=viewport,
                    device_scale_factor=1,
                    reduced_motion="reduce",
                )
                page.on("pageerror", lambda error: errors.append(str(error)))
                page.goto(f"{url}{state}", wait_until="load", timeout=120_000)
                page.locator("flt-semantics-placeholder").evaluate(
                    "element => element.click()"
                )
                page.get_by_text(
                    "Wird generiert …" if "narrow" in filename else "Generating..."
                ).wait_for(timeout=30_000)
                page.wait_for_timeout(500)
                screenshot = page.screenshot()
                rendered = Image.open(BytesIO(screenshot)).convert("RGB")
                if max(ImageStat.Stat(rendered).stddev) < 1:
                    raise RuntimeError(f"Flutter did not render {filename}")
                (OUTPUT / filename).write_bytes(screenshot)
                page.close()
            browser.close()
    finally:
        server.terminate()
        server.wait(timeout=10)
    if errors:
        raise RuntimeError(f"Browser reported page errors: {errors}")
    print(
        {
            "screenshots": [filename for filename, _, _ in cases],
            "device_pixel_ratio": 1,
            "narrow": "de-DE, 320x640 logical viewport, text scale 1.8, 180 dp card, streaming",
            "fitting": "en, 1000x800 logical viewport, text scale 1, 480 dp card, streaming",
            "theme": "light Material 3",
            "fixture": "production HtmlCodeBlockWidget with local static HTML; no network requests",
            "reduced_motion": "enabled for still captures",
            "page_errors": errors,
        }
    )


if __name__ == "__main__":
    main()
