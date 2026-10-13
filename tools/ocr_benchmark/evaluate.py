#!/usr/bin/env python3
"""Evaluate OCR predictions against the checked-in synthetic fixture manifest."""

from __future__ import annotations

import argparse
import hashlib
import json
import math
import re
import struct
import sys
import unicodedata
from pathlib import Path
from typing import Any
from urllib.parse import unquote


REQUIRED_CATEGORIES = {
    "chinese",
    "english",
    "dense_small_text",
    "rotated",
    "multi_column",
    "table",
    "formula",
    "blank",
    "low_contrast",
}
OUTPUT_FORMATS = {"plain_text", "markdown", "table", "latex"}
SECRET_SETTING_KEYS = {
    "apikey",
    "key",
    "sessionkey",
    "signingkey",
    "passwd",
    "passphrase",
    "passcode",
    "bearer",
    "accesstoken",
    "refreshtoken",
    "token",
    "authorization",
    "secret",
    "password",
    "credential",
    "credentials",
}
SUPERSCRIPT_DIGITS = str.maketrans(
    {
        "⁰": "0",
        "¹": "1",
        "²": "2",
        "³": "3",
        "⁴": "4",
        "⁵": "5",
        "⁶": "6",
        "⁷": "7",
        "⁸": "8",
        "⁹": "9",
    }
)
SUPERSCRIPT_DIGIT_SEQUENCE = re.compile(r"[⁰¹²³⁴⁵⁶⁷⁸⁹]+")
OPAQUE_CREDENTIAL_PATTERNS = (
    re.compile(r"\bsk-(?:proj-|ant-|live-|test-)?[A-Za-z0-9_-]{20,}\b", re.I),
    re.compile(r"\bsk_(?:proj|ant|live|test)_[A-Za-z0-9_-]{20,}\b", re.I),
    re.compile(r"\b(?:gh[pousr]_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{20,})\b"),
    re.compile(r"\bxox[baprs]-[A-Za-z0-9-]{15,}\b"),
    re.compile(r"\bAIza[0-9A-Za-z_-]{35}\b"),
    re.compile(r"\bAKIA[0-9A-Z]{16}\b"),
    re.compile(
        r"\beyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\b"
    ),
)
PREDICTION_FIELDS = {
    "fixture_id",
    "text",
    "elapsed_ms",
    "returned_tokens",
}
COMPARISON_METRICS = {
    "character_error_rate": ("value", "lower"),
    "page_omission_rate": ("value", "lower"),
    "reading_order_score": ("value", "higher"),
    "table_fidelity": ("value", "higher"),
    "formula_fidelity": ("value", "higher"),
    "elapsed_time_ms": ("total_ms", "lower"),
    "returned_tokens": ("total", "lower"),
}


class EvaluationError(ValueError):
    """Raised when a fixture or prediction file is malformed."""


def normalize_text(value: str) -> str:
    """Normalize to NFC, LF line endings, and collapsed Unicode whitespace."""
    line_normalized = value.replace("\r\n", "\n").replace("\r", "\n")
    return " ".join(unicodedata.normalize("NFC", line_normalized).split())


def levenshtein_distance(left: str, right: str) -> int:
    """Return code-point Levenshtein distance using two working rows."""
    if len(left) < len(right):
        left, right = right, left
    previous = list(range(len(right) + 1))
    for left_index, left_character in enumerate(left, start=1):
        current = [left_index]
        for right_index, right_character in enumerate(right, start=1):
            current.append(
                min(
                    current[-1] + 1,
                    previous[right_index] + 1,
                    previous[right_index - 1]
                    + (left_character != right_character),
                )
            )
        previous = current
    return previous[-1]


def _validated_fixtures(manifest: dict[str, Any]) -> list[dict[str, Any]]:
    fixtures = manifest.get("fixtures")
    if not isinstance(fixtures, list) or not fixtures:
        raise EvaluationError("manifest.fixtures must be a non-empty list")

    seen: set[str] = set()
    for fixture in fixtures:
        if not isinstance(fixture, dict):
            raise EvaluationError("each fixture must be an object")
        fixture_id = fixture.get("id")
        if not isinstance(fixture_id, str) or not fixture_id.strip():
            raise EvaluationError("each fixture needs a non-empty string id")
        if fixture_id in seen:
            raise EvaluationError(f"duplicate fixture id: {fixture_id}")
        seen.add(fixture_id)
        if not isinstance(fixture.get("gold_text"), str):
            raise EvaluationError(f"{fixture_id}: gold_text must be a string")
        categories = fixture.get("categories")
        if (
            not isinstance(categories, list)
            or not categories
            or any(not isinstance(category, str) for category in categories)
        ):
            raise EvaluationError(f"{fixture_id}: categories must be strings")
        for field in ("table_text", "formula_text"):
            if field in fixture and not isinstance(fixture[field], str):
                raise EvaluationError(f"{fixture_id}: {field} must be a string")
            if field in fixture and not normalize_text(fixture[field]):
                raise EvaluationError(f"{fixture_id}: {field} must not be empty")
        reading_order = fixture.get("reading_order", [])
        if not isinstance(reading_order, list) or any(
            not isinstance(anchor, str) or not normalize_text(anchor)
            for anchor in reading_order
        ):
            raise EvaluationError(
                f"{fixture_id}: reading_order must contain non-empty strings"
            )
        normalized_anchors = [normalize_text(anchor) for anchor in reading_order]
        if len(set(normalized_anchors)) != len(normalized_anchors):
            raise EvaluationError(f"{fixture_id}: reading_order anchors must be unique")
        normalized_gold = normalize_text(fixture["gold_text"])
        if any(anchor not in normalized_gold for anchor in normalized_anchors):
            raise EvaluationError(
                f"{fixture_id}: every reading_order anchor must occur in gold_text"
            )
        for field in ("table_text", "formula_text"):
            if field in fixture and normalize_text(fixture[field]) not in normalized_gold:
                raise EvaluationError(
                    f"{fixture_id}: {field} must occur in gold_text"
                )
    return fixtures


def _is_credential_like_setting_name(key: str) -> bool:
    normalized_key = re.sub(r"[^a-z]", "", key.lower())
    word_boundaries = re.sub(r"(?<=[A-Z])(?=[A-Z][a-z])", " ", key)
    word_boundaries = re.sub(r"(?<=[a-z0-9])(?=[A-Z])", " ", word_boundaries)
    key_parts = re.findall(r"[A-Za-z0-9]+", word_boundaries)
    lower_key_parts = [part.lower() for part in key_parts]
    return (
        normalized_key in SECRET_SETTING_KEYS
        or (
            normalized_key.endswith("s")
            and normalized_key[:-1] in SECRET_SETTING_KEYS
        )
        or (
            len(key_parts) > 1
            and re.fullmatch(r"key\d*", key_parts[-1], re.IGNORECASE) is not None
        )
        or (
            any(part in {"token", "tokens"} for part in lower_key_parts)
            and any(
                part
                in {
                    "api",
                    "access",
                    "auth",
                    "bearer",
                    "client",
                    "oauth",
                    "refresh",
                    "service",
                    "session",
                    "value",
                    "secret",
                    "credential",
                    "credentials",
                    "password",
                    "response",
                    "responses",
                }
                for part in lower_key_parts
            )
        )
        or normalized_key.startswith("auth")
        or "auth" in lower_key_parts
        or normalized_key.endswith("token")
        or any(
            marker in normalized_key
            for marker in (
                "apikey",
                "accesskey",
                "authorization",
                "cookie",
                "credential",
                "password",
                "privatekey",
                "secret",
            )
        )
    )


def _contains_credential_like_value(value: str) -> bool:
    decoded_value = unquote(value)
    if any(pattern.search(decoded_value) for pattern in OPAQUE_CREDENTIAL_PATTERNS):
        return True
    if re.search(r"(?i)\b(?:bearer|basic)\s+\S+", decoded_value):
        return True
    if re.search(r"(?i)://[^/:@\s]+:[^/@\s]+@", decoded_value):
        return True
    assignment_pattern = re.compile(
        r"(?i)(?:^|[?&#\s,;])([^?&#=:\s][^?&#=]*?)\s*(?:=|:(?!//))\s*([^\s&#,;]+)"
    )
    return any(
        _is_credential_like_setting_name(match.group(1).strip())
        for match in assignment_pattern.finditer(decoded_value)
    )


def _validate_safe_settings(value: Any, path: str = "settings") -> None:
    if isinstance(value, dict):
        for key, child in value.items():
            if not isinstance(key, str):
                raise EvaluationError(f"{path} keys must be strings")
            if _is_credential_like_setting_name(key):
                raise EvaluationError(
                    f"{path} contains a credential-like field name"
                )
            _validate_safe_settings(child, f"{path}.{key}")
    elif isinstance(value, list):
        for index, child in enumerate(value):
            _validate_safe_settings(child, f"{path}[{index}]")
    elif isinstance(value, str) and _contains_credential_like_value(value):
        raise EvaluationError(f"{path} contains a credential-like value")
    elif value is not None and not isinstance(value, (str, int, float, bool)):
        raise EvaluationError(f"{path} contains a non-JSON value")
    elif isinstance(value, float) and not math.isfinite(value):
        raise EvaluationError(f"{path} contains a non-finite number")


def _validated_run_and_predictions(
    input_data: dict[str, Any], fixtures: list[dict[str, Any]]
) -> tuple[dict[str, Any], dict[str, dict[str, Any]]]:
    run = input_data.get("run")
    if not isinstance(run, dict):
        raise EvaluationError("prediction input needs a run object")
    if set(run) - {"model_id", "settings", "output_format"}:
        raise EvaluationError(
            "run may contain only model_id, settings, and output_format"
        )
    model_id = run.get("model_id")
    settings = run.get("settings")
    if not isinstance(model_id, str) or not model_id.strip():
        raise EvaluationError("run.model_id must identify the evaluated model")
    if _contains_credential_like_value(model_id):
        raise EvaluationError("run.model_id contains a credential-like value")
    if not isinstance(settings, dict):
        raise EvaluationError("run.settings must contain the non-secret settings")
    _validate_safe_settings(settings)
    output_format = run.get("output_format", "plain_text")
    if not isinstance(output_format, str) or output_format not in OUTPUT_FORMATS:
        raise EvaluationError(
            f"run.output_format must be one of {sorted(OUTPUT_FORMATS)}"
        )

    raw_predictions = input_data.get("predictions")
    if not isinstance(raw_predictions, list):
        raise EvaluationError("predictions must be a list")
    fixture_ids = {fixture["id"] for fixture in fixtures}
    by_id: dict[str, dict[str, Any]] = {}
    for prediction in raw_predictions:
        if not isinstance(prediction, dict):
            raise EvaluationError("each prediction must be an object")
        unknown = set(prediction) - PREDICTION_FIELDS
        if unknown:
            raise EvaluationError(
                f"prediction contains unsupported fields: {sorted(unknown)}"
            )
        fixture_id = prediction.get("fixture_id")
        if not isinstance(fixture_id, str) or fixture_id not in fixture_ids:
            raise EvaluationError(f"unknown fixture_id: {fixture_id!r}")
        if fixture_id in by_id:
            raise EvaluationError(f"duplicate prediction for fixture: {fixture_id}")

        text = prediction.get("text")
        if text is not None and not isinstance(text, str):
            raise EvaluationError(f"{fixture_id}: text must be a string or null")
        elapsed_ms = prediction.get("elapsed_ms")
        if elapsed_ms is not None and (
            isinstance(elapsed_ms, bool)
            or not isinstance(elapsed_ms, (int, float))
            or not math.isfinite(elapsed_ms)
            or elapsed_ms < 0
        ):
            raise EvaluationError(f"{fixture_id}: elapsed_ms must be non-negative")
        returned_tokens = prediction.get("returned_tokens")
        if returned_tokens is not None and (
            isinstance(returned_tokens, bool)
            or not isinstance(returned_tokens, int)
            or returned_tokens < 0
        ):
            raise EvaluationError(
                f"{fixture_id}: returned_tokens must be a non-negative integer"
            )
        by_id[fixture_id] = {
            "text": text,
            "elapsed_ms": elapsed_ms,
            "returned_tokens": returned_tokens,
        }
    return {
        "model_id": model_id.strip(),
        "settings": settings,
        "output_format": output_format,
    }, by_id


def _table_rows(
    value: str,
    expected_column_count: int | None = None,
    *,
    allow_tsv: bool = False,
    matching_rows: set[tuple[str, ...]] | None = None,
    allow_unframed_shape_without_context: bool = False,
) -> list[tuple[str, ...]]:
    def parse_rows(
        column_count: int | None,
        *,
        infer_optional_trailing_pipe: bool = False,
        require_table_row_shape: bool = False,
    ) -> list[tuple[str, ...]]:
        lines = value.splitlines()

        def is_unframed_pipe_row(line: str) -> bool:
            stripped = line.strip()
            if (
                "|" not in stripped
                or stripped.startswith("|")
                or stripped.endswith("|")
                or not re.search(r"\s\|\s", stripped)
            ):
                return False
            cells = tuple(normalize_text(cell) for cell in stripped.split("|"))
            return column_count is None or len(cells) == column_count

        rows = []
        for line_index, line in enumerate(lines):
            if "|" not in line:
                if allow_tsv and "\t" in line:
                    cells = tuple(normalize_text(cell) for cell in line.split("\t"))
                    rows.append(cells)
                continue
            stripped = line.strip()
            has_table_row_shape = (
                stripped.startswith("|")
                or stripped.endswith("|")
                or re.search(r"\s\|\s", stripped)
            )
            first_cell = stripped.split("|", maxsplit=1)[0].strip()
            has_prose_label = re.match(
                r"\w+(?:\s+\w+)*:\s+\S", first_cell
            ) is not None
            raw_cells = stripped.split("|")
            has_leading_pipe = stripped.startswith("|")
            has_trailing_pipe = stripped.endswith("|")
            if has_leading_pipe:
                raw_cells = raw_cells[1:]
            if has_trailing_pipe and (
                has_leading_pipe
                or infer_optional_trailing_pipe
                or (
                    column_count is not None
                    and len(raw_cells) - 1 == column_count
                )
            ):
                raw_cells = raw_cells[:-1]
            cells = [normalize_text(cell) for cell in raw_cells]
            if cells and all(re.fullmatch(r":?-{3,}:?", cell) for cell in cells):
                continue
            normalized_cells = tuple(cells)
            has_unframed_table_context = any(
                0 <= neighbor_index < len(lines)
                and is_unframed_pipe_row(lines[neighbor_index])
                for neighbor_index in (line_index - 1, line_index + 1)
            )
            if (
                require_table_row_shape
                and not has_table_row_shape
                and normalized_cells not in (matching_rows or set())
            ):
                continue
            if (
                require_table_row_shape
                and has_prose_label
                and not (has_leading_pipe or has_trailing_pipe)
                and normalized_cells not in (matching_rows or set())
            ):
                continue
            if (
                require_table_row_shape
                and not (has_leading_pipe or has_trailing_pipe)
                and normalized_cells not in (matching_rows or set())
                and not has_unframed_table_context
                and not (
                    allow_unframed_shape_without_context
                    and has_table_row_shape
                )
            ):
                continue
            rows.append(normalized_cells)
        return rows

    if expected_column_count is not None:
        return parse_rows(
            expected_column_count, require_table_row_shape=True
        )

    rows = parse_rows(None, infer_optional_trailing_pipe=True)
    if not rows:
        return rows
    column_count = max(len(row) for row in rows)
    return parse_rows(column_count)


def _is_table_separator_row(value: str, expected_column_count: int) -> bool:
    stripped = value.strip()
    if "|" not in stripped:
        return False
    raw_cells = stripped.split("|")
    if stripped.startswith("|"):
        raw_cells = raw_cells[1:]
    if stripped.endswith("|"):
        raw_cells = raw_cells[:-1]
    cells = [normalize_text(cell) for cell in raw_cells]
    return len(cells) == expected_column_count and all(
        re.fullmatch(r":?-{3,}:?", cell) for cell in cells
    )


def _table_matches(expected: str, actual: str, output_format: str) -> bool:
    allow_tsv = output_format == "plain_text"
    expected_rows = _table_rows(expected, allow_tsv=allow_tsv)
    if not expected_rows:
        return normalize_text(expected) in normalize_text(actual)
    expected_column_count = max(len(row) for row in expected_rows)
    actual_rows = _table_rows(
        actual,
        expected_column_count,
        allow_tsv=allow_tsv,
        matching_rows=set(expected_rows),
    )
    return actual_rows == expected_rows


def _strip_latex_markup(value: str) -> str:
    def compact_math(match: re.Match[str]) -> str:
        return re.sub(r"\s+", "", match.group(1))

    commands = {
        "int": "∫",
        "pi": "π",
        "cdot": "·",
        "times": "×",
    }
    text = re.sub(
        r"\\(int|pi|cdot|times)(?![A-Za-z])\s*",
        lambda match: commands[match.group(1)],
        value,
    )
    text = re.sub(r"\\\((.+?)\\\)", compact_math, text, flags=re.DOTALL)
    text = re.sub(r"\\\[(.+?)\\\]", compact_math, text, flags=re.DOTALL)
    text = re.sub(r"\\(?:\(|\)|\[|\])", "", text)
    text = re.sub(
        r"(?<!\$)\$\$(.+?)\$\$(?!\$)", compact_math, text, flags=re.DOTALL
    )
    text = re.sub(
        r"(?<!\\)(?<!\$)\$(?!\$)([^$]+)\$(?!\$)(?=$|[^\w$]|[\u3400-\u9fff])",
        compact_math,
        text,
    )
    text = re.sub(r"\\([#$%&_{}])", r"\1", text)
    text = re.sub(r"\\(?:,|;|:|!|quad|qquad)\s*", " ", text)
    fraction_pattern = re.compile(
        r"\\(?:dfrac|tfrac|frac)\s*\{([^{}]+)\}\s*\{([^{}]+)\}"
    )
    square_root_pattern = re.compile(r"\\sqrt\s*\{([^{}]+)\}")

    def has_binary_operator(operand: str) -> bool:
        return re.search(r"\S\s*[-−+*/·×=<>≤≥]\s*\S", operand) is not None

    def fraction_text(match: re.Match[str]) -> str:
        def group_if_compound(operand: str) -> str:
            operand = operand.strip()
            if has_binary_operator(operand) and not (
                operand.startswith("(") and operand.endswith(")")
            ):
                return f"({operand})"
            return operand

        numerator = group_if_compound(match.group(1))
        denominator = group_if_compound(match.group(2))
        return f"{numerator}/{denominator}"

    def square_root_text(match: re.Match[str]) -> str:
        operand = match.group(1).strip()
        if has_binary_operator(operand) and not (
            operand.startswith("(") and operand.endswith(")")
        ):
            operand = f"({operand})"
        return f"√{operand}"

    while True:
        previous = text
        text = fraction_pattern.sub(fraction_text, text)
        text = square_root_pattern.sub(square_root_text, text)
        if text == previous:
            break

    def normalize_index(match: re.Match[str]) -> str:
        operator, operand = match.groups()
        if has_binary_operator(operand) and not (
            operand.startswith("(") and operand.endswith(")")
        ):
            operand = f"({operand})"
        return f"{operator}{operand}"

    return re.sub(r"([_^])\{([^{}]+)\}", normalize_index, text)


def _normalize_superscript_digits(value: str) -> str:
    return SUPERSCRIPT_DIGIT_SEQUENCE.sub(
        lambda match: "^" + match.group().translate(SUPERSCRIPT_DIGITS), value
    )


def _strip_markdown_inline_formatting(
    value: str, formula_text: str | None = None
) -> str:
    value = re.sub(r"`(.+?)`", r"\1", value)

    def delimiter_is_escaped(position: int) -> bool:
        backslash_count = 0
        position -= 1
        while position >= 0 and value[position] == "\\":
            backslash_count += 1
            position -= 1
        return backslash_count % 2 == 1

    def strip_emphasis(match: re.Match[str]) -> str:
        marker, content = match.groups()
        if delimiter_is_escaped(match.start()) or delimiter_is_escaped(
            match.end() - len(marker)
        ):
            return match.group()
        if marker != "*" or formula_text is None:
            return content

        formula_parts = re.split(r"(?<!\\)\*", formula_text)
        if len(formula_parts) < 3:
            return content

        compact_content = "".join(content.split())
        before = value[: match.start()].rstrip()
        after = value[match.end() :].lstrip()
        for part_index in range(1, len(formula_parts) - 1):
            if "".join(formula_parts[part_index].split()) != compact_content:
                continue
            previous_operand = "".join(formula_parts[part_index - 1].split())
            next_operand = "".join(formula_parts[part_index + 1].split())
            if (
                previous_operand
                and next_operand
                and before.endswith(previous_operand[-1])
                and after.startswith(next_operand[0])
            ):
                return match.group()
        return content

    value = re.sub(
        r"(\*\*|~~|\*)(?=\S)(.+?)(?<=\S)\1", strip_emphasis, value
    )

    def strip_underscore_emphasis(match: re.Match[str]) -> str:
        marker, content = match.groups()
        if delimiter_is_escaped(match.start()) or delimiter_is_escaped(
            match.end() - len(marker)
        ):
            return match.group()
        return content

    return re.sub(
        r"(?<!\w)(__|_)(?!\s)(.+?)(?<!\s)\1(?!\w)",
        strip_underscore_emphasis,
        value,
    )


def _strip_markdown_list_marker(value: str) -> str:
    return re.sub(r"^\s*(?:[-+*]|\d+[.)])\s+", "", value)


def _strip_markdown_blockquote_marker(value: str) -> str:
    return re.sub(r"^\s*>+\s?", "", value)


def _compact_annotated_formula(
    value: str, formula_text: str, output_format: str
) -> str:
    normalized_formula = _plain_text_for_cer(formula_text, output_format)
    compact_formula = "".join(normalized_formula.split())
    if not compact_formula:
        return value

    positions = [
        index for index, character in enumerate(value) if not character.isspace()
    ]
    compact_value = "".join(value[index] for index in positions)
    if compact_value.count(compact_formula) != 1:
        return value

    start = compact_value.index(compact_formula)
    first_character = positions[start]
    last_character = positions[start + len(compact_formula) - 1]
    prefix = re.sub(
        r"(?<=[\u3400-\u9fff])\s+$", "", value[:first_character]
    )
    suffix = re.sub(
        r"^\s+(?=[\u3400-\u9fff])", "", value[last_character + 1 :]
    )
    return prefix + compact_formula + suffix


def _plain_text_for_cer(
    value: str,
    output_format: str,
    table_text: str | None = None,
    formula_text: str | None = None,
    *,
    strip_markdown_markup: bool = False,
) -> str:
    text = value
    if output_format == "plain_text" and table_text:
        annotated_table_rows = set(_table_rows(table_text))
        if annotated_table_rows:
            expected_column_count = max(map(len, annotated_table_rows))
            lines = []
            for line in text.replace("\r\n", "\n").replace("\r", "\n").split("\n"):
                if _is_table_separator_row(line, expected_column_count):
                    continue
                parsed_rows = _table_rows(
                    line,
                    expected_column_count,
                    matching_rows=annotated_table_rows,
                    allow_unframed_shape_without_context=True,
                )
                if any(
                    len(row) == expected_column_count for row in parsed_rows
                ):
                    line = line.replace("|", " ")
                lines.append(line)
            text = "\n".join(lines)
    if output_format in {"markdown", "table"}:
        source_lines = text.replace("\r\n", "\n").replace("\r", "\n").split("\n")
        annotated_table_rows = set(_table_rows(table_text or ""))
        annotated_table_row_indices = set()
        for index, line in enumerate(source_lines):
            parsed_rows = _table_rows(line)
            if parsed_rows and parsed_rows[0] in annotated_table_rows:
                annotated_table_row_indices.add(index)
        separator_rows = {
            index
            for index, line in enumerate(source_lines)
            if "|" in line and not _table_rows(line)
        }
        table_rows = set()
        for separator in separator_rows:
            if separator > 0 and "|" in source_lines[separator - 1]:
                table_rows.add(separator - 1)
            row = separator + 1
            while (
                row < len(source_lines)
                and source_lines[row].strip()
                and "|" in source_lines[row]
            ):
                table_rows.add(row)
                row += 1
        lines = []
        for index, line in enumerate(source_lines):
            if index in separator_rows:
                continue
            if strip_markdown_markup:
                line = re.sub(r"^\s{0,3}#{1,6}\s+", "", line)
                line = _strip_markdown_blockquote_marker(line)
                line = _strip_markdown_list_marker(line)
                line = re.sub(r"\[([^\]]+)\]\([^)]*\)", r"\1", line)
                line = _strip_markdown_inline_formatting(line, formula_text)
            if index in table_rows or index in annotated_table_row_indices:
                line = line.replace("|", " ")
            lines.append(line)
        text = "\n".join(lines)
    if output_format in {"markdown", "table", "latex"}:
        text = _strip_latex_markup(text)
    text = _normalize_superscript_digits(text)
    text = normalize_text(text)
    if formula_text:
        text = _compact_annotated_formula(text, formula_text, output_format)
    return text


def _normalized_formula_text(
    value: str,
    output_format: str,
    *,
    strip_markdown_markup: bool = False,
    formula_text: str | None = None,
) -> str:
    text = value
    if output_format in {"markdown", "table"} and strip_markdown_markup:
        normalized_lines = (
            text.replace("\r\n", "\n").replace("\r", "\n").split("\n")
        )
        text = "\n".join(
            _strip_markdown_list_marker(_strip_markdown_blockquote_marker(line))
            for line in normalized_lines
        )
        text = _strip_markdown_inline_formatting(text, formula_text)
    text = normalize_text(text)
    if output_format in {"markdown", "table", "latex"}:
        text = _strip_latex_markup(text)

    return _normalize_superscript_digits(text)


def _canonical_formula(value: str, output_format: str) -> str:
    text = _normalized_formula_text(value, output_format)
    return re.sub(r"\s+", "", text)


def _formula_span_matches(expected: str, actual: str) -> bool:
    if not expected:
        return False
    pattern = re.compile(r"\s*".join(re.escape(character) for character in expected))
    left_operators = set("+-−*/·×^_=<>≤≥∫∮∑∏∂∇√∞")
    right_operators = left_operators
    math_functions = {
        "arccos",
        "arcsin",
        "arctan",
        "cos",
        "cosh",
        "coprod",
        "cot",
        "csc",
        "exp",
        "inf",
        "infty",
        "int",
        "iint",
        "iiint",
        "lim",
        "ln",
        "log",
        "max",
        "min",
        "nabla",
        "oint",
        "oiint",
        "partial",
        "prod",
        "sec",
        "sin",
        "sinh",
        "sqrt",
        "sum",
        "sup",
        "tan",
        "tanh",
    }
    greek_symbols = {
        "Gamma",
        "Delta",
        "Theta",
        "Lambda",
        "Xi",
        "Pi",
        "Sigma",
        "Upsilon",
        "Phi",
        "Psi",
        "Omega",
        "alpha",
        "beta",
        "chi",
        "delta",
        "epsilon",
        "eta",
        "gamma",
        "iota",
        "kappa",
        "lambda",
        "mu",
        "nu",
        "omega",
        "omicron",
        "phi",
        "pi",
        "psi",
        "rho",
        "sigma",
        "tau",
        "theta",
        "upsilon",
        "varepsilon",
        "varkappa",
        "varphi",
        "varpi",
        "varrho",
        "varsigma",
        "vartheta",
        "xi",
        "zeta",
    }

    def is_cjk_text_character(character: str) -> bool:
        return "\u3400" <= character <= "\u9fff"

    def is_formula_term(token: str) -> bool:
        latex_command = re.match(r"\\([A-Za-z]+)", token)
        function_name = latex_command.group(1) if latex_command else token
        return (
            any(character.isdigit() for character in token)
            or any(character in left_operators for character in token)
            or (
                len(token) == 1
                and token.isalpha()
                and not is_cjk_text_character(token)
            )
            or function_name in math_functions
            or function_name in greek_symbols
        )

    def has_adjacent_formula_term(value: str, *, from_right: bool) -> bool:
        tokens = value.split()
        if not tokens:
            return False
        token = tokens[0] if from_right else tokens[-1]
        if not from_right and (
            re.fullmatch(r"\d+[.)]", token)
            or re.fullmatch(r"第\d+[\u3400-\u9fff]+", token)
        ):
            return False
        has_trailing_punctuation = unicodedata.category(token[-1]).startswith("P")
        token_without_punctuation = (
            token[:-1] if has_trailing_punctuation else token
        )
        is_numeric_date = (
            re.fullmatch(
                r"(?:\d{4}[-/.]\d{1,2}[-/.]\d{1,2}|"
                r"\d{1,2}[-/.]\d{1,2}[-/.]\d{2,4})",
                token_without_punctuation,
            )
            is not None
        )
        is_date_in_prose = is_numeric_date and (
            len(tokens) == 1
            or (
                from_right
                and not is_formula_term(tokens[1])
            )
            or (
                not from_right
                and not is_formula_term(tokens[-2])
            )
        )
        if (
            not from_right
            and (
                is_date_in_prose
                or (
                    len(tokens) > 1
                    and not is_formula_term(tokens[-2])
                    and token_without_punctuation.isdigit()
                )
            )
        ):
            return False
        if (
            from_right
            and len(tokens) > 1
            and re.fullmatch(r"\d+(?:[.,]\d+)?", token_without_punctuation)
            and not is_formula_term(tokens[1])
        ):
            return False
        if from_right and is_date_in_prose:
            return False
        if not is_formula_term(token):
            return False
        if not from_right and len(token) == 1 and token.isalpha() and len(tokens) > 1:
            return is_formula_term(tokens[-2])
        return True

    for match in pattern.finditer(actual):
        before = actual[: match.start()]
        after = actual[match.end() :]
        if before:
            previous = before[-1]
            if (
                not previous.isspace()
                and (previous.isalnum() or previous in "^_")
                and not is_cjk_text_character(previous)
            ):
                continue
            previous_non_space = before.rstrip()[-1:]
            if previous_non_space in left_operators:
                continue
            if has_adjacent_formula_term(before.rstrip(), from_right=False):
                continue
        if after:
            if re.match(r"[.,]\d", after):
                continue
            following = after[0]
            if (
                not following.isspace()
                and (following.isalnum() or following in "^_")
                and not is_cjk_text_character(following)
            ):
                continue
            next_non_space = after.lstrip()[:1]
            if next_non_space in right_operators:
                continue
            if has_adjacent_formula_term(after.lstrip(), from_right=True):
                continue
        return True
    return False


def _exact_snippet_metric(
    fixtures: list[dict[str, Any]],
    predictions_by_id: dict[str, dict[str, Any]],
    field: str,
    output_format: str,
) -> dict[str, Any]:
    eligible = [fixture for fixture in fixtures if field in fixture]
    correct = 0
    pending = 0
    for fixture in eligible:
        prediction = predictions_by_id.get(fixture["id"])
        text = None if prediction is None else prediction["text"]
        normalized_text = None if text is None else normalize_text(text)
        if not normalized_text:
            pending += 1
            continue
        if field == "table_text":
            matches = _table_matches(fixture[field], text, output_format)
        else:
            expected = _canonical_formula(fixture[field], output_format)
            actual = _normalized_formula_text(
                text,
                output_format,
                strip_markdown_markup=True,
                formula_text=fixture[field],
            )
            matches = _formula_span_matches(expected, actual)
        if matches:
            correct += 1

    if not eligible:
        value = None
        status = "not_applicable"
    elif pending:
        value = None
        status = "pending"
    else:
        value = correct / len(eligible)
        status = "complete"
    return {
        "value": value,
        "correct": correct,
        "eligible": len(eligible),
        "pending": pending,
        "status": status,
    }


def _reading_order_metric(
    fixtures: list[dict[str, Any]],
    predictions_by_id: dict[str, dict[str, Any]],
) -> dict[str, Any]:
    eligible = [
        fixture
        for fixture in fixtures
        if len(fixture.get("reading_order", [])) >= 2
    ]
    expected_pairs = 0
    correct_pairs = 0
    pending_pages = 0
    for fixture in eligible:
        anchors = [normalize_text(anchor) for anchor in fixture["reading_order"]]
        expected_pairs += len(anchors) * (len(anchors) - 1) // 2
        prediction = predictions_by_id.get(fixture["id"])
        text = None if prediction is None else prediction["text"]
        if text is None:
            pending_pages += 1
            continue
        normalized_prediction = normalize_text(text)
        if not normalized_prediction:
            pending_pages += 1
            continue
        positions = [normalized_prediction.find(anchor) for anchor in anchors]
        for left_index, left_position in enumerate(positions):
            for right_position in positions[left_index + 1 :]:
                if left_position >= 0 and right_position >= 0:
                    if left_position < right_position:
                        correct_pairs += 1

    if not eligible:
        value = None
        status = "not_applicable"
    elif pending_pages:
        value = None
        status = "pending"
    else:
        value = correct_pairs / expected_pairs
        status = "complete"
    return {
        "value": value,
        "correct_pairs": correct_pairs,
        "expected_pairs": expected_pairs,
        "eligible_pages": len(eligible),
        "pending_pages": pending_pages,
        "status": status,
    }


def _usage_metric(
    fixtures: list[dict[str, Any]],
    predictions_by_id: dict[str, dict[str, Any]],
    field: str,
    total_name: str,
    mean_name: str,
) -> dict[str, Any]:
    values = []
    for fixture in fixtures:
        prediction = predictions_by_id.get(fixture["id"])
        value = None if prediction is None else prediction[field]
        if value is not None:
            values.append(value)
    pending = len(fixtures) - len(values)
    if pending:
        total = None
        mean = None
        status = "pending"
    else:
        total = sum(values)
        mean = total / len(values)
        status = "complete"
    return {
        total_name: total,
        mean_name: mean,
        "measured_pages": len(values),
        "pending_pages": pending,
        "status": status,
    }


def evaluate_predictions(
    manifest: dict[str, Any], input_data: dict[str, Any]
) -> dict[str, Any]:
    fixtures = _validated_fixtures(manifest)
    run, predictions_by_id = _validated_run_and_predictions(input_data, fixtures)

    edit_distance = 0
    reference_characters = 0
    omitted_pages = 0
    for fixture in fixtures:
        expected_value = fixture["gold_text"]
        prediction = predictions_by_id.get(fixture["id"])
        actual_value = None if prediction is None else prediction["text"]
        actual = (
            _plain_text_for_cer(
                actual_value,
                run["output_format"],
                fixture.get("table_text"),
                fixture.get("formula_text"),
                strip_markdown_markup=True,
            )
            if actual_value is not None
            else ""
        )
        expected = _plain_text_for_cer(
            expected_value,
            run["output_format"],
            fixture.get("table_text"),
            fixture.get("formula_text"),
        )
        edit_distance += levenshtein_distance(expected, actual)
        reference_characters += len(expected)
        if prediction is None or actual_value is None or (not actual and expected):
            omitted_pages += 1

    character_error_rate = {
        "value": (
            edit_distance / reference_characters if reference_characters else None
        ),
        "edit_distance": edit_distance,
        "reference_characters": reference_characters,
        "status": "complete" if reference_characters else "not_applicable",
    }
    metrics = {
        "character_error_rate": character_error_rate,
        "page_omission_rate": {
            "value": omitted_pages / len(fixtures),
            "omitted_pages": omitted_pages,
            "total_pages": len(fixtures),
            "status": "complete",
        },
        "reading_order_score": _reading_order_metric(
            fixtures, predictions_by_id
        ),
        "table_fidelity": _exact_snippet_metric(
            fixtures, predictions_by_id, "table_text", run["output_format"]
        ),
        "formula_fidelity": _exact_snippet_metric(
            fixtures, predictions_by_id, "formula_text", run["output_format"]
        ),
        "elapsed_time_ms": _usage_metric(
            fixtures,
            predictions_by_id,
            "elapsed_ms",
            "total_ms",
            "mean_ms",
        ),
        "returned_tokens": _usage_metric(
            fixtures,
            predictions_by_id,
            "returned_tokens",
            "total",
            "mean",
        ),
    }
    has_pending = any(
        metric.get("status") == "pending" for metric in metrics.values()
    )
    return {
        "schema_version": 1,
        "type": "ocr_prediction_evaluation",
        "status": "pending" if has_pending else "complete",
        "fixture_count": len(fixtures),
        "run": run,
        "metrics": metrics,
    }


def compare_reports(
    baseline: dict[str, Any], candidate: dict[str, Any]
) -> dict[str, Any]:
    comparison: dict[str, Any] = {}
    for metric_name, (field, direction) in COMPARISON_METRICS.items():
        baseline_metric = baseline["metrics"][metric_name]
        candidate_metric = candidate["metrics"][metric_name]
        baseline_value = baseline_metric.get(field)
        candidate_value = candidate_metric.get(field)
        if baseline_value is None or candidate_value is None:
            if (
                baseline_metric.get("status") == "not_applicable"
                and candidate_metric.get("status") == "not_applicable"
            ):
                status = "not_applicable"
            else:
                status = "pending"
            comparison[metric_name] = {
                "baseline": baseline_value,
                "candidate": candidate_value,
                "delta": None,
                "status": status,
            }
            continue

        delta = candidate_value - baseline_value
        if delta == 0:
            status = "unchanged"
        elif (direction == "lower" and delta > 0) or (
            direction == "higher" and delta < 0
        ):
            status = "regression"
        else:
            status = "improved"
        comparison[metric_name] = {
            "baseline": baseline_value,
            "candidate": candidate_value,
            "delta": delta,
            "status": status,
        }
    return comparison


def verify_fixtures(manifest_path: Path) -> dict[str, Any]:
    try:
        manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    except (OSError, UnicodeDecodeError, json.JSONDecodeError) as error:
        raise EvaluationError(f"cannot read fixture manifest: {error}") from error
    if not isinstance(manifest, dict):
        raise EvaluationError("fixture manifest must be an object")
    fixtures = _validated_fixtures(manifest)
    if len(fixtures) < 20:
        raise EvaluationError(
            f"expected at least 20 fixtures, found {len(fixtures)}"
        )
    categories = {
        category for fixture in fixtures for category in fixture["categories"]
    }
    missing_categories = REQUIRED_CATEGORIES - categories
    if missing_categories:
        raise EvaluationError(
            f"fixture categories are missing: {sorted(missing_categories)}"
        )

    root = manifest_path.resolve().parent
    for fixture in fixtures:
        fixture_id = fixture["id"]
        image = fixture.get("image")
        digest = fixture.get("sha256")
        if not isinstance(image, str) or not isinstance(digest, str):
            raise EvaluationError(f"{fixture_id}: image and sha256 are required")
        image_path = (root / image).resolve()
        if not image_path.is_relative_to(root):
            raise EvaluationError(f"{fixture_id}: image path escapes fixture root")
        try:
            image_bytes = image_path.read_bytes()
        except OSError as error:
            raise EvaluationError(f"{fixture_id}: cannot read {image}: {error}") from error
        if len(image_bytes) < 24 or image_bytes[:8] != b"\x89PNG\r\n\x1a\n":
            raise EvaluationError(f"{fixture_id}: fixture is not a PNG")
        width, height = struct.unpack(">II", image_bytes[16:24])
        if width < 1 or height < 1:
            raise EvaluationError(f"{fixture_id}: PNG dimensions are invalid")
        actual_digest = hashlib.sha256(image_bytes).hexdigest()
        if actual_digest != digest:
            raise EvaluationError(f"{fixture_id}: PNG SHA-256 does not match")
        if "blank" in fixture["categories"] and normalize_text(
            fixture["gold_text"]
        ):
            raise EvaluationError(f"{fixture_id}: blank fixture needs empty gold_text")
        if "table" in fixture["categories"] and "table_text" not in fixture:
            raise EvaluationError(f"{fixture_id}: table fixture needs table_text")
        if "formula" in fixture["categories"] and "formula_text" not in fixture:
            raise EvaluationError(f"{fixture_id}: formula fixture needs formula_text")

    return {
        "fixture_count": len(fixtures),
        "categories": sorted(categories),
        "images_verified": len(fixtures),
    }


def _read_json(path: Path) -> dict[str, Any]:
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, UnicodeDecodeError, json.JSONDecodeError) as error:
        raise EvaluationError(f"cannot read {path}: {error}") from error
    if not isinstance(value, dict):
        raise EvaluationError(f"{path} must contain a JSON object")
    return value


def main(argv: list[str] | None = None) -> int:
    default_manifest = Path(__file__).with_name("manifest.json")
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--manifest", type=Path, default=default_manifest)
    parser.add_argument("--predictions", type=Path)
    parser.add_argument("--baseline", type=Path)
    parser.add_argument("--output", type=Path)
    parser.add_argument(
        "--verify-fixtures",
        action="store_true",
        help="validate fixture count, coverage, PNGs, and recorded hashes",
    )
    args = parser.parse_args(argv)

    try:
        if args.verify_fixtures:
            if args.predictions or args.baseline:
                parser.error("--verify-fixtures cannot be combined with prediction files")
            result = {"status": "fixtures_verified", **verify_fixtures(args.manifest)}
        else:
            if args.predictions is None:
                parser.error("--predictions is required unless --verify-fixtures is used")
            manifest = _read_json(args.manifest)
            candidate = evaluate_predictions(
                manifest, _read_json(args.predictions)
            )
            if args.baseline is None:
                result = candidate
            else:
                baseline = evaluate_predictions(
                    manifest, _read_json(args.baseline)
                )
                comparison = compare_reports(baseline, candidate)
                result = {
                    "type": "ocr_prediction_comparison",
                    "status": (
                        "pending"
                        if baseline["status"] == "pending"
                        or candidate["status"] == "pending"
                        else "complete"
                    ),
                    "baseline": baseline,
                    "candidate": candidate,
                    "comparison": comparison,
                }
        output = json.dumps(result, ensure_ascii=False, indent=2, allow_nan=False)
        if args.output:
            args.output.write_text(output + "\n", encoding="utf-8")
        else:
            print(output)
        return 0
    except EvaluationError as error:
        print(f"evaluation error: {error}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
