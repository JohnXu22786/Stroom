from io import BytesIO
from pathlib import Path
import re
import shutil
import subprocess
import time
from urllib.request import urlopen

from PIL import Image, ImageStat
from playwright.sync_api import sync_playwright


ROOT = Path(__file__).resolve().parents[2]
OUTPUT = ROOT / "docs/qa/conversations_delete_fab"
FRAMES = OUTPUT / "frames"
PORT = 8899
URL = f"http://127.0.0.1:{PORT}/"
SERVER_LOG = OUTPUT / ".flutter-web.log"
OUTPUT.mkdir(parents=True, exist_ok=True)
FRAMES.mkdir(parents=True, exist_ok=True)


def wait_for_rendered_flutter(page):
    deadline = time.monotonic() + 120
    while time.monotonic() < deadline:
        screenshot = page.screenshot()
        rendered = Image.open(BytesIO(screenshot)).convert("RGB")
        if max(ImageStat.Stat(rendered).stddev) > 1:
            return
        page.wait_for_timeout(500)
    raise TimeoutError("Flutter Web did not render the ConversationsPage fixture")


def capture_page(page, output):
    image_bytes = page.screenshot(path=str(output))
    image = Image.open(BytesIO(image_bytes)).convert("RGB")
    red_pixels = [
        (x, y)
        for y in range(540, image.height)
        for x in range(image.width)
        if (lambda color: color[0] > 150 and color[1] < 80 and color[2] < 80)(
            image.getpixel((x, y))
        )
    ]
    if not red_pixels:
        raise RuntimeError(f"The production delete FAB is not visible in {output}")
    bounds = (
        min(x for x, _ in red_pixels),
        min(y for _, y in red_pixels),
        max(x for x, _ in red_pixels),
        max(y for _, y in red_pixels),
    )
    if bounds[0] < 0 or bounds[2] >= image.width or bounds[3] >= image.height:
        raise RuntimeError(f"Delete FAB escaped viewport in {output}: {bounds}")
    return bounds


server_log = SERVER_LOG.open("w")
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
        "tool/qa/conversations_delete_fab_capture.dart",
    ],
    cwd=ROOT,
    stdout=server_log,
    stderr=subprocess.STDOUT,
)
capture_success = False

try:
    deadline = time.monotonic() + 240
    while time.monotonic() < deadline:
        if server.poll() is not None:
            raise RuntimeError(
                "Flutter web server exited with "
                f"{server.returncode}: {SERVER_LOG.read_text()}"
            )
        try:
            with urlopen(URL, timeout=1):
                if "is being served at" in SERVER_LOG.read_text():
                    break
        except Exception:
            time.sleep(1)
    else:
        raise TimeoutError(
            f"Flutter web server did not become ready: {SERVER_LOG.read_text()}"
        )

    errors = []
    with sync_playwright() as playwright:
        browser = playwright.chromium.launch(
            headless=True,
            executable_path="/usr/bin/chromium",
            args=["--no-sandbox", "--disable-dev-shm-usage"],
        )
        page = browser.new_page(
            viewport={"width": 800, "height": 640},
            device_scale_factor=1,
            reduced_motion="no-preference",
        )
        page.on("pageerror", lambda error: errors.append(str(error)))

        def select_one(width, locale, scale):
            selection_height = 640
            page.set_viewport_size({"width": width, "height": selection_height})
            page.goto(
                f"{URL}?locale={locale}&scale={scale}",
                wait_until="load",
                timeout=180_000,
            )
            wait_for_rendered_flutter(page)
            placeholder = page.locator("flt-semantics-placeholder")
            if placeholder.count():
                placeholder.evaluate("element => element.click()")
            page.wait_for_timeout(250)
            page.mouse.click(width - 20, 28)
            page.wait_for_timeout(300)
            selected = set()
            verified_checked_rows = set()
            iterations = 0
            while len(selected) < 123 and iterations < 200:
                iterations += 1
                rows = page.locator("flt-semantics").evaluate_all(
                    "elements => elements.map(element => ({label: element.getAttribute('aria-label'), rect: element.getBoundingClientRect().toJSON()})).filter(item => item.label)"
                )
                visible_unselected = []
                for row in rows:
                    match = re.match(r"Conversation (\d+)\b", row["label"])
                    if not match:
                        continue
                    index = int(match.group(1))
                    center_y = row["rect"]["y"] + row["rect"]["height"] / 2
                    center_limit = selection_height - 20
                    if index not in selected and 70 <= center_y < center_limit:
                        visible_unselected.append((index, center_y))
                if visible_unselected:
                    index, center_y = visible_unselected[0]
                    tap_x = 8 if width <= 500 and center_y >= 550 else 36
                    page.mouse.click(tap_x, center_y)
                    page.wait_for_timeout(35)
                    row_states = page.locator("flt-semantics").evaluate_all(
                        "elements => elements.map(element => ({label: element.getAttribute('aria-label'), checked: element.getAttribute('aria-checked')})).filter(item => item.label)"
                    )
                    row_state = next(
                        (
                            row
                            for row in row_states
                            if row["label"].startswith(f"Conversation {index}\n")
                        ),
                        None,
                    )
                    if row_state and row_state["checked"] == "false":
                        raise RuntimeError(
                            f"Conversation {index} remained unchecked after its click"
                        )
                    if row_state and row_state["checked"] == "true":
                        verified_checked_rows.add(index)
                    selected.add(index)
                else:
                    if width <= 500 and iterations >= 50 and selection_height == 640:
                        selection_height = 3200
                        page.set_viewport_size(
                            {"width": width, "height": selection_height}
                        )
                        page.wait_for_timeout(400)
                        continue
                    page.mouse.move(width / 2, 450)
                    page.mouse.wheel(0, 250)
                    page.wait_for_timeout(150)
                    if iterations % 10 == 0:
                        print(
                            f"selection progress={len(selected)} "
                            f"visible labels={[row['label'] for row in rows]}",
                            flush=True,
                        )
            if len(selected) != 123:
                raise RuntimeError(
                    f"Selected {len(selected)} of 123 rows after {iterations} iterations; "
                    f"not clicked={sorted(set(range(123)) - selected)}"
                )
            page.wait_for_timeout(350)
            if selection_height != 640:
                page.set_viewport_size({"width": width, "height": 640})
                page.wait_for_timeout(400)
            return len(selected), len(verified_checked_rows)

        english_selection = select_one(800, "en", 1)
        english = OUTPUT / "delete-fab-en-800x640-scale1.png"
        english_bounds = capture_page(page, english)

        french_selection = select_one(320, "fr", 3)
        french = OUTPUT / "delete-fab-fr-320x640-scale3.png"
        french_bounds = capture_page(page, french)

        # Record one frame every 500 ms at normal playback speed. This keeps the
        # initial pause and full forward/return cycle while sampling smoothly.
        frame_rate = 2
        duration_seconds = 36
        frame_count = frame_rate * duration_seconds
        start = time.monotonic()
        for index in range(frame_count):
            page.screenshot(path=str(FRAMES / f"frame-{index:03d}.png"))
            target = start + (index + 1) / frame_rate
            delay = target - time.monotonic()
            if delay > 0:
                time.sleep(delay)

        page_errors = errors.copy()
        browser.close()

    if page_errors:
        raise RuntimeError(f"Browser reported page errors: {page_errors}")

    subprocess.run(
        [
            "ffmpeg",
            "-hide_banner",
            "-loglevel",
            "error",
            "-y",
            "-framerate",
            str(frame_rate),
            "-i",
            str(FRAMES / "frame-%03d.png"),
            "-vf",
            "crop=288:56:16:568",
            "-c:v",
            "libvpx-vp9",
            "-pix_fmt",
            "yuv420p",
            str(OUTPUT / "delete-fab-fr-320x640-scale3-reveal-return.webm"),
        ],
        check=True,
    )
    shutil.rmtree(FRAMES)
    print(
        {
            "screenshots": [english.name, french.name],
            "preview": "delete-fab-fr-320x640-scale3-reveal-return.webm",
            "preview_seconds": duration_seconds,
            "preview_frames": frame_count,
            "frame_rate": frame_rate,
            "viewport_css_px": "320x640 / 800x640",
            "delete_fab_red_bounds": {
                "english": english_bounds,
                "french": french_bounds,
            },
            "selection": {
                "english_selected_rows": english_selection[0],
                "english_checked_aria_verified": english_selection[1],
                "french_selected_rows": french_selection[0],
                "french_checked_aria_verified": french_selection[1],
            },
            "device_pixel_ratio": 1,
            "fixture": "production ConversationsPage, 123 in-memory conversations selected through UI",
            "page_errors": page_errors,
        }
    )
    capture_success = True
finally:
    server.terminate()
    try:
        server.wait(timeout=10)
    except subprocess.TimeoutExpired:
        server.kill()
        server.wait()
    server_log.close()
    if capture_success:
        SERVER_LOG.unlink(missing_ok=True)
    else:
        print(f"Flutter web server log preserved at {SERVER_LOG}")
        if SERVER_LOG.exists():
            print(SERVER_LOG.read_text())
