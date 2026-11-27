import argparse
import socket
import subprocess
import sys
import tempfile
import time
from pathlib import Path
from io import BytesIO

from PIL import Image
from playwright.sync_api import sync_playwright


ROOT = Path(__file__).resolve().parents[2]
OUTPUT = ROOT / "docs/qa/bounded-format-icon"
WEB = Path("/tmp/stroom-text-storage-format-badge-web")
OUTPUT.mkdir(parents=True, exist_ok=True)


def badge_blue_pixels(image: Image.Image) -> int:
    badge_area = image.convert("RGB").crop((20, 120, 80, 260))
    return sum(
        1
        for red, green, blue in badge_area.get_flattened_data()
        if blue > red * 1.08 and blue > green * 1.02 and blue - red > 15
    )


def wait_for_badge(page, timeout_ms: int = 120_000) -> bytes:
    elapsed = 0
    while elapsed < timeout_ms:
        screenshot = page.screenshot()
        if badge_blue_pixels(Image.open(BytesIO(screenshot))) >= 10:
            return screenshot
        page.wait_for_timeout(250)
        elapsed += 250
    raise RuntimeError("The format badge did not become visible")


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
                "tool/qa/text_storage_format_badge_capture.dart",
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
            captures = [
                ("1", "light", True, "text-storage-html-320x640-1x-light.png"),
                ("4", "light", True, "text-storage-html-320x640-4x-light.png"),
                ("4", "dark", True, "text-storage-html-320x640-4x-dark.png"),
            ]
            for scale, theme, reduced, filename in captures:
                page = browser.new_page(
                    viewport={"width": 320, "height": 640},
                    device_scale_factor=1,
                    reduced_motion="reduce" if reduced else "no-preference",
                )
                page.on("pageerror", lambda error: errors.append(str(error)))
                page.goto(
                    f"http://127.0.0.1:{port}/?locale=fr-FR&scale={scale}"
                    f"&theme={theme}&reducedMotion={str(reduced).lower()}",
                    wait_until="load",
                    timeout=120_000,
                )
                page.wait_for_timeout(8_000)
                page.screenshot(path=str(OUTPUT / filename))
                page.close()

            page = browser.new_page(
                viewport={"width": 320, "height": 640},
                device_scale_factor=1,
                reduced_motion="no-preference",
            )
            page.on("pageerror", lambda error: errors.append(str(error)))
            page.goto(
                f"http://127.0.0.1:{port}/?locale=fr-FR&scale=4&theme=dark",
                wait_until="load",
                timeout=120_000,
            )
            initial_frame = wait_for_badge(page)
            with tempfile.TemporaryDirectory(
                prefix="stroom-text-storage-format-"
            ) as frame_dir:
                frames = Path(frame_dir)
                (frames / "frame-000.png").write_bytes(initial_frame)
                for frame in range(1, 56):
                    page.screenshot(path=str(frames / f"frame-{frame:03d}.png"))
                    page.wait_for_timeout(250)
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
                        str(OUTPUT / "text-storage-html-4x-dark-reveal.webm"),
                    ],
                    check=True,
                )
            browser.close()

        for _, _, _, filename in captures:
            image = Image.open(OUTPUT / filename)
            if image.size != (320, 640):
                raise RuntimeError(f"Unexpected capture size for {filename}: {image.size}")
            blue_pixels = badge_blue_pixels(image)
            if blue_pixels < 10:
                raise RuntimeError(
                    f"The format label was not visible in {filename}"
                )
        if errors:
            raise RuntimeError(f"Browser page errors: {errors}")
    finally:
        server.terminate()
        server.wait(timeout=10)
    print(
        {
            "viewport": "320x640 CSS px, DPR 1",
            "locale": "fr-FR",
            "text_scale": "1x fitting and 4x enlarged",
            "theme": "light and dark",
            "reduced_motion": "all static captures respect reduced motion; the WebM uses normal motion",
            "fixture": "local HTML TextRecord in production TextStoragePage",
            "page_errors": errors,
        }
    )


if __name__ == "__main__":
    main()
