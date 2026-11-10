#!/usr/bin/env python3
"""Validate that every native macOS menu title has English and Chinese text."""

from __future__ import annotations

import re
import sys
import xml.etree.ElementTree as ET
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
MENU = ROOT / "macos/Runner/Base.lproj/MainMenu.xib"
PROJECT = ROOT / "macos/Runner.xcodeproj/project.pbxproj"
LOCALES = ("en", "zh-Hans")
STRING_ENTRY = re.compile(r'^\s*"([^"\\]+)\.title"\s*=\s*"((?:\\.|[^"\\])*)";\s*$')


def read_localized_titles(path: Path) -> dict[str, str]:
    titles: dict[str, str] = {}
    for line_number, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
        if not line.strip() or line.lstrip().startswith("//"):
            continue
        match = STRING_ENTRY.match(line)
        if not match:
            raise ValueError(f"{path}:{line_number}: invalid localized title entry")
        object_id, value = match.groups()
        if object_id in titles:
            raise ValueError(f"{path}:{line_number}: duplicate title for {object_id}")
        titles[object_id] = value
    return titles


def main() -> int:
    root = ET.parse(MENU).getroot()
    title_elements = [
        element
        for element in root.iter()
        if element.tag in {"menu", "menuItem", "window"} and element.get("title")
    ]
    source_titles = {element.get("id"): element.get("title") for element in title_elements}
    if None in source_titles:
        raise ValueError("Every titled menu and window element must have an Interface Builder ID")
    if any("APP_NAME" in title for title in source_titles.values()):
        raise ValueError("MainMenu.xib still contains the APP_NAME placeholder")

    project = PROJECT.read_text(encoding="utf-8")
    if "zh-Hans" not in project or "en.lproj/MainMenu.strings" not in project or "zh-Hans.lproj/MainMenu.strings" not in project:
        raise ValueError("Runner.xcodeproj must register English and Simplified Chinese MainMenu strings")

    for locale in LOCALES:
        path = ROOT / f"macos/Runner/{locale}.lproj/MainMenu.strings"
        if not path.is_file():
            raise ValueError(f"Missing {locale} MainMenu.strings")
        localized = read_localized_titles(path)
        missing = sorted(set(source_titles) - set(localized))
        extra = sorted(set(localized) - set(source_titles))
        if missing or extra:
            raise ValueError(f"{locale} title IDs do not match MainMenu.xib (missing={missing}, extra={extra})")
        empty = sorted(object_id for object_id, value in localized.items() if not value.strip())
        if empty:
            raise ValueError(f"{locale} has empty menu titles for {empty}")
        if any("APP_NAME" in value for value in localized.values()):
            raise ValueError(f"{locale} MainMenu.strings still contains the APP_NAME placeholder")
        if locale == "en":
            mismatched = sorted(
                object_id
                for object_id, source_title in source_titles.items()
                if localized[object_id] != source_title
            )
            if mismatched:
                raise ValueError(f"English titles differ from the Base XIB for {mismatched}")

    print("macOS MainMenu has explicit English and Simplified Chinese titles for every titled object.")
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except (OSError, ET.ParseError, ValueError) as error:
        print(f"macOS menu localization validation failed: {error}", file=sys.stderr)
        sys.exit(1)
