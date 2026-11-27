import argparse
import hashlib
import socket
import subprocess
import sys
import tempfile
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

            reveal_page = browser.new_page(
                viewport={"width": 320, "height": 640},
                device_scale_factor=1,
                reduced_motion="no-preference",
            )
            reveal_page.on("pageerror", lambda error: errors.append(str(error)))
            reveal_page.goto(
                f"http://127.0.0.1:{port}/?locale=fr-FR&scale=4&theme=dark"
                "&reducedMotion=false",
                wait_until="load",
                timeout=120_000,
            )
            reveal_page.wait_for_timeout(500)
            with tempfile.TemporaryDirectory(
                prefix="stroom-text-storage-actions-reveal-"
            ) as frame_dir:
                frames = Path(frame_dir)
                frame_hashes = set()
                for frame in range(48):
                    frame_path = frames / f"frame-{frame:03d}.png"
                    frame_bytes = reveal_page.screenshot(path=str(frame_path))
                    frame_hashes.add(hashlib.sha256(frame_bytes).digest())
                    reveal_page.wait_for_timeout(250)
                if len(frame_hashes) < 8:
                    raise RuntimeError(
                        "The production 4× action labels did not visibly move"
                    )
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
                        str(
                            OUTPUT
                            / "text-storage-actions-narrow-4x-dark-reveal.webm"
                        ),
                    ],
                    check=True,
                )
            reveal_page.close()
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
            "screenshots_reduced_motion": True,
            "reveal_capture": (
                "320x640 French 4× dark production page, normal motion, 12-second WebM"
            ),
            "page_errors": errors,
            "screenshots": [item[2:] for item in captures],
            "reveal_video": "text-storage-actions-narrow-4x-dark-reveal.webm",
        }
    )


if __name__ == "__main__":
    main()
