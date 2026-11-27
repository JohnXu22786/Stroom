import asyncio
from email.parser import BytesHeaderParser
from pathlib import Path
import subprocess
import tempfile
import time
from urllib.parse import urlsplit

ROOT = Path(__file__).resolve().parents[2]
OUTPUT = ROOT / "docs/qa/asr_task_title"
WEB = Path("/tmp/stroom-asr-task-title-web")
URL = "http://127.0.0.1:8878"
OUTPUT.mkdir(parents=True, exist_ok=True)


def wait_for_fixture_server(server, fixture_bundle, url, timeout=10):
    expected_bundle = fixture_bundle.read_bytes()
    deadline = time.monotonic() + timeout
    parsed_url = urlsplit(url)
    bundle_path = f"{parsed_url.path.rstrip('/')}/main.dart.js"
    while True:
        if server.poll() is not None:
            raise RuntimeError(
                "Local ASR fixture server exited before becoming ready; "
                "port 8878 may already be in use"
            )
        try:
            remaining = deadline - time.monotonic()
            if remaining <= 0:
                raise _readiness_timeout(timeout)
            response = asyncio.run(
                _read_fixture_response(
                    parsed_url.hostname,
                    parsed_url.port,
                    bundle_path,
                    len(expected_bundle),
                    remaining,
                )
            )
            if response != expected_bundle:
                raise RuntimeError(
                    "Port 8878 is serving a different fixture; refusing to capture"
                )
            if server.poll() is not None:
                raise _port_conflict()
            return
        except TimeoutError:
            raise _readiness_timeout(timeout) from None
        except OSError:
            if time.monotonic() >= deadline:
                raise _readiness_timeout(timeout) from None
            time.sleep(min(0.1, deadline - time.monotonic()))


def _port_conflict():
    return RuntimeError(
        "Local ASR fixture server exited before becoming ready; "
        "port 8878 may already be in use"
    )


def _readiness_timeout(timeout):
    return RuntimeError(
        f"Local ASR fixture server did not become ready within {timeout} seconds"
    )


async def _read_fixture_response(host, port, path, expected_size, timeout):
    async with asyncio.timeout(timeout):
        reader, writer = await asyncio.open_connection(host, port)
        try:
            writer.write(
                (
                    f"GET {path} HTTP/1.1\r\n"
                    f"Host: {host}:{port}\r\n"
                    "Connection: close\r\n\r\n"
                ).encode("ascii")
            )
            await writer.drain()
            try:
                header_bytes = await reader.readuntil(b"\r\n\r\n")
            except asyncio.IncompleteReadError:
                raise RuntimeError(
                    "Port 8878 is serving a different fixture; refusing to capture"
                ) from None
            status_line, _, header_lines = header_bytes[:-4].partition(b"\r\n")
            try:
                status = int(status_line.split(b" ", 2)[1])
                headers = BytesHeaderParser().parsebytes(
                    header_lines + b"\r\n\r\n"
                )
                content_length = int(headers["Content-Length"])
            except (IndexError, TypeError, ValueError):
                raise RuntimeError(
                    "Port 8878 is serving a different fixture; refusing to capture"
                ) from None
            if status != 200 or content_length != expected_size:
                raise RuntimeError(
                    "Port 8878 is serving a different fixture; refusing to capture"
                )
            try:
                return await reader.readexactly(expected_size)
            except asyncio.IncompleteReadError:
                raise RuntimeError(
                    "Port 8878 is serving a different fixture; refusing to capture"
                ) from None
        finally:
            writer.close()
            await writer.wait_closed()


def main():
    subprocess.run(
        [
            "flutter",
            "build",
            "web",
            "--release",
            "--no-pub",
            "--target",
            "tool/qa/asr_task_title_capture.dart",
            "--output",
            str(WEB),
            "--no-wasm-dry-run",
        ],
        cwd=ROOT,
        check=True,
    )
    server = subprocess.Popen(
        [
            "python3",
            "-m",
            "http.server",
            "8878",
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
        wait_for_fixture_server(server, WEB / "main.dart.js", URL)
        from playwright.sync_api import sync_playwright

        with sync_playwright() as playwright:
            browser = playwright.chromium.launch(
                headless=True,
                executable_path="/usr/bin/chromium",
                args=["--no-sandbox", "--disable-dev-shm-usage"],
            )
            for reduced_motion, output_name in [
                ("reduce", "asr-task-title-320x640-1x.png"),
                ("no-preference", None),
            ]:
                context = browser.new_context(
                    viewport={"width": 320, "height": 640},
                    device_scale_factor=1,
                    reduced_motion=reduced_motion,
                )
                page = context.new_page()
                page.on("pageerror", lambda error: errors.append(str(error)))
                page.goto(f"{URL}/?locale=en-US&theme=light&scale=1", wait_until="load")
                page.wait_for_timeout(10_000)
                if page.evaluate("devicePixelRatio") != 1:
                    raise RuntimeError("Expected a 1x browser device scale factor")
                if output_name is not None:
                    page.screenshot(path=str(OUTPUT / output_name))
                else:
                    with tempfile.TemporaryDirectory(prefix="stroom-asr-task-title-") as frame_dir:
                        frames = Path(frame_dir)
                        for frame in range(32):
                            page.screenshot(path=str(frames / f"frame-{frame:03d}.png"))
                            page.wait_for_timeout(250)
                        subprocess.run(
                            [
                                "ffmpeg", "-hide_banner", "-loglevel", "error", "-y",
                                "-framerate", "4", "-i", str(frames / "frame-%03d.png"),
                                "-c:v", "libvpx-vp9", "-b:v", "1M", "-pix_fmt",
                                "yuv420p", str(OUTPUT / "asr-task-title-motion-320x640-1x.webm"),
                            ],
                            check=True,
                        )
                context.close()
            browser.close()
        if errors:
            raise RuntimeError(f"Browser reported runtime errors: {errors}")
    finally:
        server.terminate()
        server.wait(timeout=10)
    print({"viewport": "320x640", "device_scale_factor": 1, "locale": "en-US", "theme": "light", "text_scale": 1, "page_errors": errors})


if __name__ == "__main__":
    main()
