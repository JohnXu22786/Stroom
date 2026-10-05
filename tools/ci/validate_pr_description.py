#!/usr/bin/env python3
"""Validate the required structure of a pull request description."""

from __future__ import annotations

import json
import re
import sys
import unicodedata
from pathlib import Path

from langdetect import DetectorFactory, LangDetectException, detect_langs

DetectorFactory.seed = 0

HEADING_PATTERN = re.compile(r"^#{1,6}\s+.+$")
FENCE_PATTERN = re.compile(r"^ {0,3}(`{3,}|~{3,})(.*)$")
FENCE_CLOSE_PATTERN = re.compile(r"^ {0,3}(`+|~+)[ \t]*$")
INLINE_CODE_PATTERN = re.compile(
    r"(?<!\\)(`+)(?!`).*?(?<!`)\1(?!`)", re.DOTALL
)
PLACEHOLDER_PATTERN = re.compile(
    r"\[\s*\]"
    r"|\[(?:type|summary|description|placeholder|todo|tbd|write|describe|add|"
    r"fill|enter|replace|insert|choose)"
    r"[^\]]*\]"
    r"|^[ \t]*(?:TODO|TBD|FIXME|PLACEHOLDER)(?:[ \t]*[:—-][^\n]*)?[ \t]*$"
    r"|^[ \t]*Fixes\s+#[ \t]*$"
    r"|^[ \t]*To be (?:filled in|determined)[.!]?[ \t]*$",
    re.IGNORECASE | re.MULTILINE,
)
TEMPLATE_INSTRUCTION_PATTERN = re.compile(
    r"^[ \t]*(?:(?:[-*+]|\d+\.)[ \t]+|>[ \t]*)?"
    r"(?:Describe the behavior or state before these changes\."
    r"|Describe the resulting behavior or state\..*"
    r"|Enter the applicable type, such as .*"
    r"|Describe backwards-incompatible changes, or write None\..*"
    r"|Write the PR description in English\..*"
    r"|Add Fixes #123 here only when this PR closes an issue\.)[ \t]*$",
    re.IGNORECASE | re.MULTILINE,
)
REQUIRED_HEADINGS = (
    "## What this PR does",
    "### Before this PR:",
    "### After this PR:",
    "### Type of change",
)
OPTIONAL_HEADING = "### Breaking changes (if any)"


def _remove_code_blocks(body: str) -> str:
    lines: list[str] = []
    active_fence: tuple[str, int] | None = None
    for line in body.splitlines():
        if active_fence is not None:
            closing = FENCE_CLOSE_PATTERN.fullmatch(line)
            if (
                closing
                and closing.group(1)[0] == active_fence[0]
                and len(closing.group(1)) >= active_fence[1]
            ):
                active_fence = None
            continue

        opening = FENCE_PATTERN.match(line)
        if opening:
            marker, info = opening.groups()
            if marker[0] != "`" or "`" not in info:
                active_fence = (marker[0], len(marker))
                continue
        if line.startswith("\t") or line.startswith("    "):
            continue
        lines.append(line)
    return "\n".join(lines)


def _strip_comments(body: str) -> tuple[str, bool]:
    parts: list[str] = []
    cursor = 0
    while True:
        start = body.find("<!--", cursor)
        if start < 0:
            parts.append(body[cursor:])
            return "".join(parts), False
        parts.append(body[cursor:start])
        end = body.find("-->", start + 4)
        if end < 0:
            return "".join(parts), True
        cursor = end + 3


def _remove_inline_code_spans(body: str) -> str:
    return INLINE_CODE_PATTERN.sub(
        lambda match: "\n" * match.group().count("\n"), body
    )


def _clean_body(body: str) -> tuple[str, bool]:
    without_fences = _remove_code_blocks(body)
    without_inline_code = _remove_inline_code_spans(without_fences)
    return _strip_comments(without_inline_code)


def _heading_name(line: str) -> str | None:
    indentation = len(line) - len(line.lstrip(" "))
    if indentation > 3:
        return None
    heading = line[indentation:].rstrip()
    return heading if HEADING_PATTERN.fullmatch(heading) else None


def _section_content(lines: list[str], heading_index: int) -> str:
    end = next(
        (
            index
            for index in range(heading_index + 1, len(lines))
            if _heading_name(lines[index]) is not None
        ),
        len(lines),
    )
    return "\n".join(lines[heading_index + 1 : end]).strip()


def _is_english_prose(content: str) -> bool:
    try:
        languages = detect_langs(content)
    except LangDetectException:
        return False
    return languages[0].lang == "en" and languages[0].prob >= 0.8


def _contains_template_placeholder(content: str) -> bool:
    return bool(
        PLACEHOLDER_PATTERN.search(content)
        or TEMPLATE_INSTRUCTION_PATTERN.search(content)
    )


def validate_pr_body(body: str) -> list[str]:
    """Return formatting errors for a PR body; an empty list means it is valid."""
    if not body.strip():
        return ["The pull request description is empty."]

    cleaned_body, has_unclosed_comment = _clean_body(body)
    errors: list[str] = []
    if has_unclosed_comment:
        errors.append("Close every HTML comment in the PR description.")
    if any(
        character.isalpha()
        and not unicodedata.name(character, "").startswith("LATIN ")
        for character in cleaned_body
    ):
        errors.append(
            "Write the pull request description in English using Latin-script text."
        )

    lines = cleaned_body.splitlines()
    heading_indices: dict[str, list[int]] = {}
    for index, line in enumerate(lines):
        heading = _heading_name(line)
        if heading is not None:
            heading_indices.setdefault(heading, []).append(index)

    required_indices: list[int] = []
    for heading in REQUIRED_HEADINGS:
        indices = heading_indices.get(heading, [])
        if not indices:
            errors.append(f'Missing required heading: "{heading}".')
            continue
        if len(indices) > 1:
            errors.append(f'Use the heading only once: "{heading}".')
        required_indices.append(indices[0])

    optional_indices = heading_indices.get(OPTIONAL_HEADING, [])
    if len(optional_indices) > 1:
        errors.append(f'Use the heading only once: "{OPTIONAL_HEADING}".')

    ordered_indices = required_indices + optional_indices[:1]
    if len(ordered_indices) == len(REQUIRED_HEADINGS) + min(1, len(optional_indices)):
        if ordered_indices != sorted(ordered_indices):
            errors.append("Use the PR headings in the order shown by the template.")

    for heading in REQUIRED_HEADINGS:
        indices = heading_indices.get(heading, [])
        if not indices:
            continue
        content = _section_content(lines, indices[0])
        if not content:
            errors.append(f'The "{heading}" section must contain text.')
        elif _contains_template_placeholder(content):
            errors.append(
                f'The "{heading}" section still contains a template '
                "placeholder or instruction."
            )

        if heading in REQUIRED_HEADINGS[:3] and content:
            if not _is_english_prose(content):
                errors.append(f'The "{heading}" section must be written in English.')

    if optional_indices and not _section_content(lines, optional_indices[0]):
        errors.append(
            f'The "{OPTIONAL_HEADING}" section must describe changes or be omitted.'
        )
    elif optional_indices:
        breaking_content = _section_content(lines, optional_indices[0])
        if _contains_template_placeholder(breaking_content):
            errors.append(
                f'The "{OPTIONAL_HEADING}" section still contains a template '
                "placeholder or instruction."
            )
        elif (
            breaking_content.casefold().strip(" .!\t\n") != "none"
            and not _is_english_prose(breaking_content)
        ):
            errors.append(
                f'The "{OPTIONAL_HEADING}" section must be written in English.'
            )

    return errors


def main() -> int:
    if len(sys.argv) != 2:
        print(f"Usage: {Path(sys.argv[0]).name} <github-event.json>", file=sys.stderr)
        return 2

    try:
        event = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as error:
        print(f"Could not read the GitHub event payload: {error}", file=sys.stderr)
        return 2

    pull_request = event.get("pull_request")
    if not isinstance(pull_request, dict):
        print("The PR description check requires a pull_request event.", file=sys.stderr)
        return 2

    errors = validate_pr_body(pull_request.get("body") or "")
    if errors:
        print("PR description format check failed:")
        for error in errors:
            print(f"- {error}")
        return 1

    print("PR description format check passed.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
