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
    "accesstoken",
    "refreshtoken",
    "token",
    "authorization",
    "secret",
    "password",
    "credential",
    "credentials",
}
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


def _validate_safe_settings(value: Any, path: str = "settings") -> None:
    if isinstance(value, dict):
        for key, child in value.items():
            if not isinstance(key, str):
                raise EvaluationError(f"{path} keys must be strings")
            normalized_key = re.sub(r"[^a-z]", "", key.lower())
            credential_like = (
                normalized_key in SECRET_SETTING_KEYS
                or normalized_key.startswith("auth")
                or normalized_key.startswith("token")
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
            if credential_like:
                raise EvaluationError(
                    f"{path} contains a credential-like field name: {key}"
                )
            _validate_safe_settings(child, f"{path}.{key}")
    elif isinstance(value, list):
        for index, child in enumerate(value):
            _validate_safe_settings(child, f"{path}[{index}]")
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


def _table_rows(value: str) -> list[tuple[str, ...]]:
    rows = []
    for line in value.splitlines():
        if "|" not in line:
            continue
        stripped = line.strip()
        raw_cells = stripped.split("|")
        if stripped.startswith("|"):
            raw_cells = raw_cells[1:]
        if stripped.endswith("|"):
            raw_cells = raw_cells[:-1]
        cells = [normalize_text(cell) for cell in raw_cells]
        if cells and all(re.fullmatch(r":?-{3,}:?", cell) for cell in cells):
            continue
        rows.append(tuple(cells))
    return rows


def _table_matches(expected: str, actual: str) -> bool:
    expected_rows = _table_rows(expected)
    if not expected_rows:
        return normalize_text(expected) in normalize_text(actual)
    actual_rows = _table_rows(actual)
    return actual_rows == expected_rows


def _canonical_formula(value: str, output_format: str) -> str:
    text = normalize_text(value)
    if output_format in {"markdown", "latex"}:
        text = re.sub(r"\\(?:\(|\)|\[|\])|\${1,2}", "", text)
        text = re.sub(r"\\(?:,|;|:|!|quad|qquad)\s*", "", text)
        commands = {
            r"\int": "∫",
            r"\pi": "π",
            r"\cdot": "·",
            r"\times": "×",
        }
        text = re.sub(
            r"\\(?:int|pi|cdot|times)(?![A-Za-z])",
            lambda match: commands[match.group()],
            text,
        )
        fraction_pattern = re.compile(
            r"\\(?:dfrac|tfrac|frac)\s*\{([^{}]+)\}\s*\{([^{}]+)\}"
        )
        while fraction_pattern.search(text):
            text = fraction_pattern.sub(r"\1/\2", text)
        text = re.sub(r"([_^])\{([^{}]+)\}", r"\1\2", text)

    for superscript, plain in {
        "⁰": "^0",
        "¹": "^1",
        "²": "^2",
        "³": "^3",
        "⁴": "^4",
        "⁵": "^5",
        "⁶": "^6",
        "⁷": "^7",
        "⁸": "^8",
        "⁹": "^9",
    }.items():
        text = text.replace(superscript, plain)
    return re.sub(r"\s+", "", text)


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
            matches = _table_matches(fixture[field], text)
        else:
            expected = _canonical_formula(fixture[field], output_format)
            actual = _canonical_formula(text, output_format)
            matches = expected in actual
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
        expected = normalize_text(fixture["gold_text"])
        prediction = predictions_by_id.get(fixture["id"])
        actual_value = None if prediction is None else prediction["text"]
        actual = normalize_text(actual_value) if actual_value is not None else ""
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
    except (OSError, json.JSONDecodeError) as error:
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
    except (OSError, json.JSONDecodeError) as error:
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
