#!/usr/bin/env python3
"""Validate the required structure of a pull request description."""

from __future__ import annotations

import json
import re
import sys
import unicodedata
from pathlib import Path

COMMENT_PATTERN = re.compile(r"<!--.*?-->", re.DOTALL)
HEADING_PATTERN = re.compile(r"^#{1,6}\s+.+$")
FENCE_PATTERN = re.compile(r"^\s*(`{3,}|~{3,})")

REQUIRED_HEADINGS = (
    "## What this PR does",
    "### Before this PR:",
    "### After this PR:",
    "### Type of change",
)
OPTIONAL_HEADING = "### Breaking changes (if any)"


def _clean_body(body: str) -> str:
    body_without_comments = COMMENT_PATTERN.sub("", body)
    lines: list[str] = []
    active_fence: str | None = None
    for line in body_without_comments.splitlines():
        fence = FENCE_PATTERN.match(line)
        if active_fence is None:
            if fence:
                active_fence = fence.group(1)[0]
                continue
            lines.append(line)
            continue
        if fence and fence.group(1)[0] == active_fence:
            active_fence = None
    return "\n".join(lines)


def _section_content(lines: list[str], heading_index: int) -> str:
    end = next(
        (
            index
            for index in range(heading_index + 1, len(lines))
            if HEADING_PATTERN.match(lines[index].strip())
        ),
        len(lines),
    )
    return "\n".join(lines[heading_index + 1 : end]).strip()


def validate_pr_body(body: str) -> list[str]:
    """Return formatting errors for a PR body; an empty list means it is valid."""
    if not body.strip():
        return ["The pull request description is empty."]

    cleaned_body = _clean_body(body)
    errors: list[str] = []
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
        heading = line.strip()
        if HEADING_PATTERN.fullmatch(heading):
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
        elif heading == "### Type of change" and content.casefold() == "[type]":
            errors.append('Replace the "[type]" placeholder with a change type.')

    if optional_indices and not _section_content(lines, optional_indices[0]):
        errors.append(
            f'The "{OPTIONAL_HEADING}" section must describe changes or be omitted.'
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
