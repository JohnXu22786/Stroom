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
PROJECT_OBJECT = re.compile(
    r"(?ms)^\t\t([0-9A-F]{24})(?:\s*/\*.*?\*/)?\s*=\s*\{(.*?)\};"
)


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
