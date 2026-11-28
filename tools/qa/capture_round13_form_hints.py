from io import BytesIO
from pathlib import Path
import subprocess
import tempfile
import time
from urllib.request import urlopen

from PIL import Image, ImageStat
from playwright.sync_api import sync_playwright


ROOT = Path(__file__).resolve().parents[2]
OUTPUT = ROOT / "docs/ui-constrained-text-qa/round13-form-hints-a"
PREVIEW = OUTPUT / "custom-json-hint-reveal-de-320x640-scale1_8-light.webm"
PORT = 8899
URL = f"http://127.0.0.1:{PORT}/"
OUTPUT.mkdir(parents=True, exist_ok=True)


def wait_for_rendered_flutter(page):
    deadline = time.monotonic() + 120
    while time.monotonic() < deadline:
        image = Image.open(BytesIO(page.screenshot())).convert("RGB")
        if max(ImageStat.Stat(image).stddev) > 1:
            return
        page.wait_for_timeout(300)
    raise TimeoutError("Flutter Web did not render the form-hint fixture")


def focus_json_field(page):
    placeholder = page.locator("flt-semantics-placeholder")
    if placeholder.count():
        placeholder.evaluate("element => element.click()")
    text_fields = page.get_by_role("textbox")
    if text_fields.count() >= 4:
        text_fields.last.fill("x")
        text_fields.last.fill("")
    else:
        page.mouse.click(100, 520)
    page.wait_for_timeout(100)


with tempfile.TemporaryDirectory(prefix="round13-form-hints-") as temp_dir:
    temp = Path(temp_dir)
    server_log_path = temp / "flutter-web.log"
    frames = temp / "frames"
    frames.mkdir()
    with server_log_path.open("w") as server_log:
        server = subprocess.Popen(
            [
                "flutter",
                "run",
                "--release",
                "--no-pub",
                "-d",
                "web-server",
                "--web-hostname",
                "127.0.0.1",
                "--web-port",
                str(PORT),
                "--target",
                "tools/qa/round13_form_hints_capture.dart",
            ],
            cwd=ROOT,
            stdout=server_log,
            stderr=subprocess.STDOUT,
        )
        try:
            deadline = time.monotonic() + 240
            while time.monotonic() < deadline:
                if server.poll() is not None:
                    raise RuntimeError(
                        f"Flutter web server exited ({server.returncode}):\n"
                        f"{server_log_path.read_text()}"
                    )
                try:
                    with urlopen(URL, timeout=1):
                        if "is being served at" in server_log_path.read_text():
                            break
                except Exception:
                    pass
                time.sleep(1)
            else:
                raise TimeoutError(
                    f"Flutter web server did not become ready:\n"
                    f"{server_log_path.read_text()}"
                )

            errors = []
            with sync_playwright() as playwright:
                browser = playwright.chromium.launch(
                    headless=True,
                    executable_path="/usr/bin/chromium",
                    args=["--no-sandbox", "--disable-dev-shm-usage"],
                )
                page = browser.new_page(
                    viewport={"width": 320, "height": 640},
                    device_scale_factor=1,
                    reduced_motion="no-preference",
                )
                page.on("pageerror", lambda error: errors.append(str(error)))

                for theme in ("light", "dark"):
                    page.goto(f"{URL}?theme={theme}", wait_until="load", timeout=120_000)
                    wait_for_rendered_flutter(page)
                    focus_json_field(page)
                    screenshot = page.screenshot()
                    rendered = Image.open(BytesIO(screenshot)).convert("RGB")
                    if rendered.size != (320, 640):
                        raise RuntimeError(f"Unexpected screenshot size: {rendered.size}")
                    (OUTPUT / f"custom-json-clipped-de-320x640-scale1_8-{theme}.png").write_bytes(
                        screenshot
                    )

                page.goto(f"{URL}?theme=light", wait_until="load", timeout=120_000)
                wait_for_rendered_flutter(page)
                focus_json_field(page)
                duration_seconds = 10
                frames_per_second = 8
                frame_count = duration_seconds * frames_per_second
                frame_interval = 1 / frames_per_second
                start = time.monotonic()
                for index in range(frame_count):
                    page.screenshot(path=str(frames / f"frame-{index:03d}.png"))
                    target = start + (index + 1) * frame_interval
                    delay = target - time.monotonic()
                    if delay > 0:
                        time.sleep(delay)

                device_pixel_ratio = page.evaluate("devicePixelRatio")
                browser.close()
        finally:
            server.terminate()
            try:
                server.wait(timeout=10)
            except subprocess.TimeoutExpired:
                server.kill()
                server.wait()

    if errors:
        raise RuntimeError(f"Browser reported runtime errors: {errors}")
    if device_pixel_ratio != 1:
        raise RuntimeError(f"Unexpected device pixel ratio: {device_pixel_ratio}")

    subprocess.run(
        [
            "ffmpeg",
            "-y",
            "-framerate",
            str(frames_per_second),
            "-i",
            str(frames / "frame-%03d.png"),
            "-c:v",
            "libvpx-vp9",
            "-pix_fmt",
            "yuv420p",
            "-b:v",
            "500k",
            str(PREVIEW),
        ],
        check=True,
        stdout=subprocess.DEVNULL,
    )

print(
    {
        "preview": str(PREVIEW.relative_to(ROOT)),
        "captures": [
            "custom-json-clipped-de-320x640-scale1_8-light.png",
            "custom-json-clipped-de-320x640-scale1_8-dark.png",
        ],
        "viewport_css_px": {"width": 320, "height": 640},
        "device_pixel_ratio": 1,
        "locale": "de_DE",
        "themes": ["light preview", "dark screenshot"],
        "text_scale": 1.8,
        "preview_duration_seconds": duration_seconds,
        "preview_frames": frame_count,
        "page_errors": errors,
    }
)
