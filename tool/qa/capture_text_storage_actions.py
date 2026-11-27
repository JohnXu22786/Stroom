import argparse
import socket
import subprocess
import sys
import time
from pathlib import Path

from PIL import Image
from playwright.sync_api import sync_playwright


ROOT = Path(__file__).resolve().parents[2]
OUTPUT = ROOT / "docs/qa/text_storage_constrained_labels"
WEB = Path("/tmp/stroom-text-storage-actions-web")
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
                "tool/qa/text_storage_actions_capture.dart",
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
        [
            sys.executable,
            "-m",
            "http.server",
            str(port),
            "--bind",
            "127.0.0.1",
            "--directory",
            str(WEB),
        ],
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
            captures = []
            for width, height, layout in [
                (320, 640, "narrow"),
                (800, 640, "wide"),
            ]:
                for scale in [1, 4]:
                    for theme in ["light", "dark"]:
                        captures.append(
                            (width, height, layout, scale, theme)
                        )

            for width, height, layout, scale, theme in captures:
                page = browser.new_page(
                    viewport={"width": width, "height": height},
                    device_scale_factor=1,
                    reduced_motion="reduce",
                )
                page.on("pageerror", lambda error: errors.append(str(error)))
                page.goto(
                    f"http://127.0.0.1:{port}/?locale=fr-FR&scale={scale}"
                    f"&theme={theme}",
                    wait_until="load",
                    timeout=120_000,
                )
                page.wait_for_timeout(5_000)
                filename = (
                    f"text-storage-actions-{layout}-{scale}x-{theme}.png"
                )
                page.screenshot(path=str(OUTPUT / filename))
                image = Image.open(OUTPUT / filename)
                if image.size != (width, height):
                    raise RuntimeError(
                        f"Unexpected capture size for {filename}: {image.size}"
                    )
                page.close()
            browser.close()

        if errors:
            raise RuntimeError(f"Browser page errors: {errors}")
    finally:
        server.terminate()
        server.wait(timeout=10)
    print(
        {
            "viewport": "320x640 narrow and 800x640 wide CSS px, DPR 1",
            "locale": "fr-FR",
            "text_scale": "1x and 4x",
            "theme": "light and dark",
            "fixture": "production TextStoragePage with local empty storage",
            "reduced_motion": True,
            "page_errors": errors,
            "screenshots": [item[2:] for item in captures],
        }
    )


if __name__ == "__main__":
    main()
