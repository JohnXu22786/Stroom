#!/usr/bin/env python3
"""Capture the production dropdown label components at a narrow viewport."""

from pathlib import Path
import subprocess

from playwright.sync_api import sync_playwright


ROOT = Path(__file__).resolve().parents[2]
OUTPUT = ROOT / "docs/ui-constrained-text-qa/llm-account-dropdowns"
FRAMES = OUTPUT / "frames"
BASE_URL = "http://127.0.0.1:8879"
WIDTH = 320
HEIGHT = 640
FRAME_COUNT = 128
FRAME_INTERVAL_MS = 125


def main() -> None:
    OUTPUT.mkdir(parents=True, exist_ok=True)
    FRAMES.mkdir(parents=True, exist_ok=True)
    with sync_playwright() as playwright:
        browser = playwright.chromium.launch(
            headless=True,
            executable_path="/usr/bin/chromium",
            args=[
                "--no-sandbox",
                "--enable-webgl",
                "--use-gl=angle",
                "--use-angle=swiftshader",
            ],
        )
        screenshot_page = browser.new_page(
            viewport={"width": WIDTH, "height": HEIGHT},
            device_scale_factor=1,
        )
        _open_fixture(screenshot_page, "off")
        screenshot_page.wait_for_timeout(400)
        screenshot_page.screenshot(
            path=str(OUTPUT / "account-dropdowns-fr-320x640-scale1-light.png")
        )
        screenshot_page.mouse.click(172, 289)
        screenshot_page.wait_for_timeout(250)
        screenshot_page.screenshot(
            path=str(OUTPUT / "account-dropdown-menu-fr-320x640-scale1-light.png")
        )

        motion_page = browser.new_page(
            viewport={"width": WIDTH, "height": HEIGHT},
            device_scale_factor=1,
        )
        _open_fixture(motion_page, "on")
        for frame in range(FRAME_COUNT):
            motion_page.screenshot(
                path=str(FRAMES / f"frame-{frame:03d}.png")
            )
            motion_page.wait_for_timeout(FRAME_INTERVAL_MS)
        browser.close()

    subprocess.run(
        [
            "ffmpeg",
            "-y",
            "-framerate",
            "8",
            "-i",
            str(FRAMES / "frame-%03d.png"),
            "-c:v",
            "libvpx-vp9",
            "-crf",
            "30",
            "-b:v",
            "0",
            "-pix_fmt",
            "yuv420p",
            str(OUTPUT / "account-dropdown-motion-preview.webm"),
        ],
        check=True,
    )
    for frame in FRAMES.iterdir():
        frame.unlink()
    FRAMES.rmdir()


def _open_fixture(page, motion: str) -> None:
    errors = []
    page.on("pageerror", lambda error: errors.append(str(error)))
    page.goto(
        f"{BASE_URL}/?locale=fr-FR&theme=light&scale=1&motion={motion}",
        wait_until="networkidle",
    )
    page.wait_for_timeout(1800)
    if errors:
        raise RuntimeError("Flutter fixture error: " + "; ".join(errors))
    canvas = page.locator("canvas").first.bounding_box()
    if canvas is None or canvas["width"] == 0 or canvas["height"] == 0:
        raise RuntimeError("Flutter fixture did not render its production controls")


if __name__ == "__main__":
    main()
