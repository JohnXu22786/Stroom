#!/usr/bin/env python3
"""Validate the required structure of a pull request description."""

from __future__ import annotations

import json
import re
import sys
import unicodedata
from pathlib import Path

HEADING_PATTERN = re.compile(r"^#{1,6}\s+.+$")
FENCE_PATTERN = re.compile(r"^ {0,3}(`{3,}|~{3,})(.*)$")
FENCE_CLOSE_PATTERN = re.compile(r"^ {0,3}(`+|~+)[ \t]*$")
PLACEHOLDER_PATTERN = re.compile(
    r"\[(?:type|summary|description|placeholder|todo|tbd|write|describe|add)"
    r"[^\]]*\]"
    r"|^[ \t]*(?:TODO|TBD|FIXME|PLACEHOLDER)(?:[ \t]*[:—-][^\n]*)?[ \t]*$"
    r"|^[ \t]*Fixes\s+#[ \t]*$"
    r"|^[ \t]*To be (?:filled in|determined)[.!]?[ \t]*$",
    re.IGNORECASE | re.MULTILINE,
)
ENGLISH_WORDS = frozenset(
    "a about after all also an and any are as at be because been before being but "
    "by can change changed changes check checks could did do does each every for "
    "from had has have he her here him his how if in into is it its may more most "
    "must new no not of off on one or other our out over same she should so some "
    "such than that the their them then there these they this those through to "
    "under until up use used uses using was we were what when where which while "
    "who will with without would you your add adds added adding fix fixes fixed "
    "improve improves improved keep keeps kept show shows remove removes removed "
    "replace replaces replaced allow allows ensure ensures require requires "
    "support supports update updates updated run runs test tests work works "
    "screen page startup description section template format workflow behavior "
    "color colors palette migration state status progress breaking none always "
    "single same independent regardless complete across full"
    .split()
)
NON_ENGLISH_MARKERS = frozenset(
    "después cuando cambia ejecuta migración migracion pantalla inicio siempre usa"
    " del los las una uno para pero por que se sin está esta son con desde"
    " après apres chaque démarrage demarrage page écran ecran change dans avec"
    " pour sur qui est une des les le la du au aux cette ces elle il nous vous sont et"
    " wird beim jeder die das der den dem eine einer und mit nicht von zum zur"
    " auf bei sich ist sind für für immer verwendet ändert geandert"
    " depois quando muda tela inicial usa para mas por que uma dos das não nao"
    " della della ogni avvio cambia sempre usa con per che sono il lo gli"
    " wordt iedere startscherm altijd gebruikt voor maar niet het een de"
    .split()
)
WORD_PATTERN = re.compile(r"[^\W_]+", re.UNICODE)

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


def _clean_body(body: str) -> tuple[str, bool]:
    return _strip_comments(_remove_code_blocks(body))


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
    words = set(WORD_PATTERN.findall(content.casefold()))
    english_indicators = words & ENGLISH_WORDS
    foreign_indicators = words & NON_ENGLISH_MARKERS
    minimum_english_indicators = 1 if len(words) < 4 else 2
    return (
        len(english_indicators) >= minimum_english_indicators
        and len(foreign_indicators) < 2
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
        elif PLACEHOLDER_PATTERN.search(content):
            errors.append(f'The "{heading}" section still contains a placeholder.')

        if heading in REQUIRED_HEADINGS[:3] and content:
            if not _is_english_prose(content):
                errors.append(f'The "{heading}" section must be written in English.')

    if optional_indices and not _section_content(lines, optional_indices[0]):
        errors.append(
            f'The "{OPTIONAL_HEADING}" section must describe changes or be omitted.'
        )
    elif optional_indices:
        breaking_content = _section_content(lines, optional_indices[0])
        if PLACEHOLDER_PATTERN.search(breaking_content):
            errors.append(
                f'The "{OPTIONAL_HEADING}" section still contains a placeholder.'
            )
        elif breaking_content.casefold().strip(" .!\t\n") != "none" and not _is_english_prose(
            breaking_content
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
