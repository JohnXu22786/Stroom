#!/usr/bin/env python3
"""Validate that every native macOS menu title has English and Chinese text."""

from __future__ import annotations

import posixpath
import re
import sys
import xml.etree.ElementTree as ET
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
MENU = ROOT / "macos/Runner/Base.lproj/MainMenu.xib"
PROJECT = ROOT / "macos/Runner.xcodeproj/project.pbxproj"
LOCALES = ("en", "zh-Hans")
STRING_ENTRY = re.compile(r'^\s*"([^"\\]+)\.title"\s*=\s*"((?:\\.|[^"\\])*)";\s*$')
LOCALIZED_LINE_BREAKS = frozenset("\n\v\f\r\x1c\x1d\x1e\x85\u2028\u2029")
PROJECT_OBJECT = re.compile(
    r"(?ms)^\t\t([0-9A-F]{24})(?:\s*/\*.*?\*/)?\s*=\s*\{(.*?)\};"
)
# Unicode mappings for the 0x80–0xFF range of Apple's NeXTSTEP Latin octal
# escapes, from Unicode's NEXTSTEP.TXT mapping table.
NEXTSTEP_LATIN_HIGH = (
    0x00A0, 0x00C0, 0x00C1, 0x00C2, 0x00C3, 0x00C4, 0x00C5, 0x00C7,
    0x00C8, 0x00C9, 0x00CA, 0x00CB, 0x00CC, 0x00CD, 0x00CE, 0x00CF,
    0x00D0, 0x00D1, 0x00D2, 0x00D3, 0x00D4, 0x00D5, 0x00D6, 0x00D9,
    0x00DA, 0x00DB, 0x00DC, 0x00DD, 0x00DE, 0x00B5, 0x00D7, 0x00F7,
    0x00A9, 0x00A1, 0x00A2, 0x00A3, 0x2044, 0x00A5, 0x0192, 0x00A7,
    0x00A4, 0x2019, 0x201C, 0x00AB, 0x2039, 0x203A, 0xFB01, 0xFB02,
    0x00AE, 0x2013, 0x2020, 0x2021, 0x00B7, 0x00A6, 0x00B6, 0x2022,
    0x201A, 0x201E, 0x201D, 0x00BB, 0x2026, 0x2030, 0x00AC, 0x00BF,
    0x00B9, 0x02CB, 0x00B4, 0x02C6, 0x02DC, 0x00AF, 0x02D8, 0x02D9,
    0x00A8, 0x00B2, 0x02DA, 0x00B8, 0x00B3, 0x02DD, 0x02DB, 0x02C7,
    0x2014, 0x00B1, 0x00BC, 0x00BD, 0x00BE, 0x00E0, 0x00E1, 0x00E2,
    0x00E3, 0x00E4, 0x00E5, 0x00E7, 0x00E8, 0x00E9, 0x00EA, 0x00EB,
    0x00EC, 0x00C6, 0x00ED, 0x00AA, 0x00EE, 0x00EF, 0x00F0, 0x00F1,
    0x0141, 0x00D8, 0x0152, 0x00BA, 0x00F2, 0x00F3, 0x00F4, 0x00F5,
    0x00F6, 0x00E6, 0x00F9, 0x00FA, 0x00FB, 0x0131, 0x00FC, 0x00FD,
    0x0142, 0x00F8, 0x0153, 0x00DF, 0x00FE, 0x00FF, 0xFFFD, 0xFFFD,
)


def _localized_line_number(text: str, index: int) -> int:
    return sum(char in LOCALIZED_LINE_BREAKS for char in text[:index]) + 1


def _strip_project_comments(text: str) -> str:
    result = []
    index = 0
    in_string = False
    escaped = False
    while index < len(text):
        char = text[index]
        if in_string:
            result.append(char)
            if escaped:
                escaped = False
            elif char == "\\":
                escaped = True
            elif char == '"':
                in_string = False
            index += 1
        elif char == '"':
            in_string = True
            result.append(char)
            index += 1
        elif text.startswith("/*", index):
            end = text.find("*/", index + 2)
            if end == -1:
                result.append(text[index:])
                break
            result.extend("\n" for value in text[index : end + 2] if value == "\n")
            index = end + 2
        elif text.startswith("//", index):
            end = text.find("\n", index + 2)
            if end == -1:
                break
            index = end
        else:
            result.append(char)
            index += 1
    return "".join(result)


def _project_objects(project: str) -> dict[str, str]:
    project = _strip_project_comments(project)
    return {match.group(1): match.group(2) for match in PROJECT_OBJECT.finditer(project)}


def _project_object_array(body: str, field: str) -> set[str]:
    body = _strip_project_comments(body)
    match = re.search(rf"\b{re.escape(field)}\s*=\s*\((.*?)\);", body, re.DOTALL)
    if not match:
        return set()
    return set(re.findall(r"\b[0-9A-F]{24}\b", match.group(1)))


def _project_object_value(body: str, field: str) -> str | None:
    body = _strip_project_comments(body)
    match = re.search(
        rf'\b{re.escape(field)}\s*=\s*(?:"((?:\\.|[^"])*)"|([^;\s]+))'
        rf'(?:\s*/\*.*?\*/)?\s*;',
        body,
    )
    if not match:
        return None
    return match.group(1) if match.group(1) is not None else match.group(2)


def _group_locations(objects: dict[str, str], project_root: str) -> dict[str, str]:
    locations: dict[str, str] = {}
    groups = {
        group_id: body
        for group_id, body in objects.items()
        if _project_object_value(body, "isa") in {"PBXGroup", "PBXVariantGroup"}
    }
    child_groups = {
        child_id
        for body in groups.values()
        for child_id in _project_object_array(body, "children")
        if child_id in groups
    }

    def visit(group_id: str, parent_path: str, ancestors: set[str]) -> None:
        if group_id in ancestors:
            return
        body = objects.get(group_id, "")
        if _project_object_value(body, "isa") not in {"PBXGroup", "PBXVariantGroup"}:
            return
        source_tree = _project_object_value(body, "sourceTree")
        if source_tree == "<group>":
            base_path = parent_path
        elif source_tree in {"SOURCE_ROOT", "PROJECT_DIR"}:
            base_path = project_root
        else:
            return
        group_path = posixpath.normpath(
            posixpath.join(base_path, _project_object_value(body, "path") or "")
        )
        locations[group_id] = group_path
        next_ancestors = ancestors | {group_id}
        for child_id in _project_object_array(body, "children"):
            visit(child_id, group_path, next_ancestors)

    for root_group in set(groups) - child_groups:
        visit(root_group, project_root, set())
    return locations


def _file_reference_location(
    body: str, group_path: str, project_root: str
) -> str | None:
    source_tree = _project_object_value(body, "sourceTree")
    if source_tree == "<group>":
        base_path = group_path
    elif source_tree in {"SOURCE_ROOT", "PROJECT_DIR"}:
        base_path = project_root
    else:
        return None
    path = _project_object_value(body, "path")
    if path is None:
        return None
    return posixpath.normpath(posixpath.join(base_path, path))


def _project_target_ids(project: str) -> set[str]:
    project = _strip_project_comments(project)
    root_object = _project_object_value(project, "rootObject")
    if root_object is None:
        return set()
    targets = set()
    for match in re.finditer(
        r"(?m)^\t\t([0-9A-F]{24})(?:\s*/\*.*?\*/)?\s*=\s*\{", project
    ):
        if match.group(1) != root_object:
            continue
        body_start = match.end()
        depth = 1
        in_string = False
        escaped = False
        for index in range(body_start, len(project)):
            char = project[index]
            if in_string:
                if escaped:
                    escaped = False
                elif char == "\\":
                    escaped = True
                elif char == '"':
                    in_string = False
            elif char == '"':
                in_string = True
            elif char == "{":
                depth += 1
            elif char == "}":
                depth -= 1
                if depth == 0:
                    body = project[body_start:index]
                    if _project_object_value(body, "isa") == "PBXProject":
                        targets.update(_project_object_array(body, "targets"))
                    break
    return targets


def has_localization_build_membership(project: str, localized_paths: dict[str, str]) -> bool:
    """Return whether Runner builds one variant group containing every localized file."""
    objects = _project_objects(project)
    project_root = "macos"
    group_locations = _group_locations(objects, project_root)
    expected_paths = {
        posixpath.normpath(posixpath.join(project_root, "Runner", path))
        for path in localized_paths.values()
    }
    project_targets = _project_target_ids(project)
    runner_targets = {
        object_id
        for object_id, body in objects.items()
        if _project_object_value(body, "isa") == "PBXNativeTarget"
        and _project_object_value(body, "name") == "Runner"
        and _project_object_value(body, "productType")
        == "com.apple.product-type.application"
        and object_id in project_targets
    }
    for target_id in runner_targets:
        target = objects[target_id]
        for phase_id in _project_object_array(target, "buildPhases"):
            phase = objects.get(phase_id, "")
            if _project_object_value(phase, "isa") != "PBXResourcesBuildPhase":
                continue
            resource_groups = set()
            for build_file_id in _project_object_array(phase, "files"):
                build_file = objects.get(build_file_id, "")
                if _project_object_value(build_file, "isa") != "PBXBuildFile":
                    continue
                file_ref = _project_object_value(build_file, "fileRef")
                if file_ref and _project_object_value(objects.get(file_ref, ""), "isa") == "PBXVariantGroup":
                    resource_groups.add(file_ref)

            for group_id in resource_groups:
                group_path = group_locations.get(group_id)
                if group_path is None:
                    continue
                children = _project_object_array(objects[group_id], "children")
                paths = set()
                for child_id in children:
                    file_reference = objects.get(child_id, "")
                    if _project_object_value(file_reference, "isa") != "PBXFileReference":
                        continue
                    path = _file_reference_location(
                        file_reference, group_path, project_root
                    )
                    if path is not None:
                        paths.add(path)
                if expected_paths.issubset(paths):
                    return True
    return False


def _strip_localized_comments(text: str, path: Path) -> tuple[str, set[int]]:
    result = list(text)
    comment_line_breaks: set[int] = set()
    index = 0
    in_string = False
    escaped = False
    while index < len(text):
        char = text[index]
        if in_string:
            if escaped:
                escaped = False
            elif char == "\\":
                escaped = True
            elif char == '"':
                in_string = False
            index += 1
        elif char == '"':
            in_string = True
            index += 1
        elif text.startswith("/*", index):
            end = text.find("*/", index + 2)
            if end == -1:
                line_number = _localized_line_number(text, index)
                raise ValueError(f"{path}:{line_number}: unterminated block comment")
            end += 2
            for comment_index in range(index, end):
                if text[comment_index] in LOCALIZED_LINE_BREAKS:
                    comment_line_breaks.add(comment_index)
                else:
                    result[comment_index] = " "
            index = end
        elif text.startswith("//", index):
            end = index + 2
            while end < len(text) and text[end] not in LOCALIZED_LINE_BREAKS:
                end += 1
            for comment_index in range(index, end):
                result[comment_index] = " "
            index = end
        else:
            index += 1
    return "".join(result), comment_line_breaks


def _decode_localized_value(value: str) -> str:
    escapes = {
        "a": "\a",
        "b": "\b",
        "f": "\f",
        "n": "\n",
        "r": "\r",
        "t": "\t",
        "v": "\v",
        "\\": "\\",
        '"': '"',
    }
    decoded = []
    index = 0
    while index < len(value):
        if value[index] != "\\":
            decoded.append(value[index])
            index += 1
            continue

        index += 1
        if index == len(value):
            raise ValueError("trailing backslash")

        escape = value[index]
        if escape in escapes:
            decoded.append(escapes[escape])
            index += 1
        elif escape in "01234567":
            end = index + 1
            while end < len(value) and end < index + 3 and value[end] in "01234567":
                end += 1
            octet = int(value[index:end], 8)
            if octet > 0xFF:
                raise ValueError("octal escape exceeds one byte")
            decoded.append(
                chr(octet if octet < 0x80 else NEXTSTEP_LATIN_HIGH[octet - 0x80])
            )
            index = end
        elif escape == "U":
            digits = value[index + 1 : index + 5]
            if len(digits) != 4 or any(char not in "0123456789abcdefABCDEF" for char in digits):
                raise ValueError("invalid Unicode escape")
            decoded.append(chr(int(digits, 16)))
            index += 5
        else:
            raise ValueError("unsupported escape")

    result = "".join(decoded)
    try:
        return result.encode("utf-16-be", "surrogatepass").decode("utf-16-be")
    except UnicodeDecodeError as error:
        raise ValueError("unpaired Unicode surrogate") from error


def read_localized_titles(path: Path) -> dict[str, str]:
    titles: dict[str, str] = {}
    content, comment_line_breaks = _strip_localized_comments(
        path.read_text(encoding="utf-8"), path
    )

    def add_entry(statement: str, start: int) -> None:
        first_character = next(
            (index for index, char in enumerate(statement) if not char.isspace()),
            None,
        )
        if first_character is None:
            return
        line_number = _localized_line_number(content, start + first_character)
        if any(
            char in LOCALIZED_LINE_BREAKS and start + index not in comment_line_breaks
            for index, char in enumerate(statement[first_character:], first_character)
        ):
            raise ValueError(f"{path}:{line_number}: invalid localized title entry")
        match = STRING_ENTRY.fullmatch(statement)
        if not match:
            raise ValueError(f"{path}:{line_number}: invalid localized title entry")
        object_id, value = match.groups()
        if object_id in titles:
            raise ValueError(f"{path}:{line_number}: duplicate title for {object_id}")
        try:
            titles[object_id] = _decode_localized_value(value)
        except ValueError as error:
            raise ValueError(
                f"{path}:{line_number}: invalid localized title entry"
            ) from error

    start = 0
    in_string = False
    escaped = False
    for index, char in enumerate(content):
        if in_string:
            if escaped:
                escaped = False
            elif char == "\\":
                escaped = True
            elif char == '"':
                in_string = False
        elif char == '"':
            in_string = True
        elif char == ";":
            add_entry(content[start : index + 1], start)
            start = index + 1
    add_entry(content[start:], start)
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
    localized_paths = {
        locale: f"{locale}.lproj/MainMenu.strings" for locale in LOCALES
    }
    if not has_localization_build_membership(project, localized_paths):
        raise ValueError(
            "Runner.xcodeproj must include English and Simplified Chinese MainMenu strings "
            "in a variant group built by the Runner resources phase"
        )

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
