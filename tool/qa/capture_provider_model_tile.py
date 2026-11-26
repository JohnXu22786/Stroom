from pathlib import Path
import socket
import subprocess
import tempfile
import time

from playwright.sync_api import sync_playwright


ROOT = Path(__file__).resolve().parents[2]
OUTPUT = ROOT / "docs/qa/provider_model_tile"
WEB = Path("/tmp/stroom-provider-model-tile-web")
OUTPUT.mkdir(parents=True, exist_ok=True)


def main() -> None:
    subprocess.run(
        [
            "flutter",
            "build",
            "web",
            "--release",
            "--no-pub",
            "--target",
            "tool/qa/provider_model_tile_capture.dart",
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

            fitting = browser.new_context(
                viewport={"width": 1000, "height": 800},
                device_scale_factor=1,
                reduced_motion="reduce",
            )
            page = fitting.new_page()
            page.on("pageerror", lambda error: errors.append(str(error)))
            page.goto(
                f"{url}?state=fitting&locale=en&scale=1&theme=light",
                wait_until="load",
            )
            page.wait_for_timeout(1_500)
            page.screenshot(path=str(OUTPUT / "fitting-en-1000x800-scale1-light.png"))
            fitting.close()

            narrow = browser.new_context(
                viewport={"width": 320, "height": 640},
                device_scale_factor=1,
                reduced_motion="no-preference",
            )
            page = narrow.new_page()
            page.on("pageerror", lambda error: errors.append(str(error)))
            page.goto(
                f"{url}?state=overflow&locale=de-DE&scale=1.8&theme=light",
                wait_until="load",
            )
            page.wait_for_timeout(1_500)
            page.screenshot(
                path=str(OUTPUT / "narrow-de-320x640-scale1_8-light.png")
            )
            with tempfile.TemporaryDirectory(prefix="stroom-provider-model-tile-") as frame_dir:
                frames = Path(frame_dir)
                for frame in range(48):
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
                        str(OUTPUT / "narrow-de-reveal-320x640-scale1_8-light.webm"),
                    ],
                    check=True,
                )
            narrow.close()
            browser.close()
        if errors:
            raise RuntimeError(f"Browser reported page errors: {errors}")
    finally:
        server.terminate()
        server.wait(timeout=10)
    print(
        {
            "viewport": "320x640 CSS px at DPR 1; 1000x800 CSS px at DPR 1",
            "locale": "de-DE overflow; en fitting baseline",
            "scale": "1.8 overflow; 1.0 fitting baseline",
            "direction": "LTR",
            "theme": "light",
            "fixture": "synthetic local provider/model; no network request",
            "page_errors": errors,
        }
    )


if __name__ == "__main__":
    main()
