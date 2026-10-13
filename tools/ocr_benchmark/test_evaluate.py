import json
import unittest
from contextlib import redirect_stdout
from io import StringIO
from pathlib import Path
from tempfile import TemporaryDirectory

from evaluate import (
    EvaluationError,
    compare_reports,
    evaluate_predictions,
    main,
    verify_fixtures,
)


ROOT = Path(__file__).resolve().parent


def small_manifest():
    return {
        "fixtures": [
            {
                "id": "ordered-lines",
                "gold_text": "AB",
                "reading_order": ["A", "B"],
                "categories": ["english", "multi_column"],
            },
            {
                "id": "formula",
                "gold_text": "e\u0301",
                "formula_text": "\u00e9",
                "categories": ["english", "formula"],
            },
            {
                "id": "table",
                "gold_text": "xy",
                "table_text": "xy",
                "categories": ["english", "table"],
            },
            {
                "id": "blank",
                "gold_text": "",
                "categories": ["blank"],
            },
        ]
    }


def predictions(results):
    return {
        "run": {
            "model_id": "offline-evaluator-test",
            "settings": {"temperature": 0},
        },
        "predictions": results,
    }


class EvaluateTests(unittest.TestCase):
    def test_credential_like_setting_names_are_rejected(self):
        for key in (
            "api_token",
            "authorization_header",
            "auth_header",
            "access_key",
            "private_key",
            "password",
            "cookie",
            "session_cookie",
            "SESSION.Cookie",
            "cookieHeader",
        ):
            with self.subTest(key=key):
                input_data = predictions([])
                input_data["run"]["settings"] = {key: "redacted-test-value"}
                with self.assertRaises(EvaluationError):
                    evaluate_predictions(small_manifest(), input_data)

    def test_safe_run_settings_are_retained(self):
        input_data = predictions([])
        input_data["run"]["settings"] = {
            "temperature": 0.2,
            "region": "test-region",
        }

        report = evaluate_predictions(small_manifest(), input_data)

        self.assertEqual(report["run"]["settings"], input_data["run"]["settings"])

    def test_empty_fidelity_annotations_are_rejected(self):
        for field in ("table_text", "formula_text"):
            with self.subTest(field=field):
                manifest = small_manifest()
                fixture = next(
                    fixture
                    for fixture in manifest["fixtures"]
                    if field in fixture
                )
                fixture[field] = "  "
                with self.assertRaises(EvaluationError):
                    evaluate_predictions(manifest, predictions([]))

    def test_empty_prediction_text_keeps_content_metrics_pending(self):
        report = evaluate_predictions(
            small_manifest(),
            predictions(
                [
                    {"fixture_id": "ordered-lines", "text": ""},
                    {"fixture_id": "table", "text": ""},
                ]
            ),
        )

        metrics = report["metrics"]
        self.assertIsNone(metrics["reading_order_score"]["value"])
        self.assertEqual(metrics["reading_order_score"]["pending_pages"], 1)
        self.assertIsNone(metrics["table_fidelity"]["value"])
        self.assertEqual(metrics["table_fidelity"]["pending"], 1)

    def test_markdown_table_separator_does_not_reduce_table_fidelity(self):
        manifest = {
            "fixtures": [
                {
                    "id": "table",
                    "gold_text": "Code | Count | Total\nP-12 | 3 | 15.00\nQ-07 | 2 | 8.00",
                    "table_text": "Code | Count | Total\nP-12 | 3 | 15.00\nQ-07 | 2 | 8.00",
                    "categories": ["english", "table"],
                }
            ]
        }
        report = evaluate_predictions(
            manifest,
            predictions(
                [
                    {
                        "fixture_id": "table",
                        "text": (
                            "| Code | Count | Total |\n"
                            "| --- | ---: | ---: |\n"
                            "| P-12 | 3 | 15.00 |\n"
                            "| Q-07 | 2 | 8.00 |"
                        ),
                    }
                ]
            ),
        )

        self.assertEqual(report["metrics"]["table_fidelity"]["value"], 1)

    def test_extra_table_row_reduces_table_fidelity(self):
        expected = "Code | Count | Total\nP-12 | 3 | 15.00\nQ-07 | 2 | 8.00"
        manifest = {
            "fixtures": [
                {
                    "id": "table",
                    "gold_text": expected,
                    "table_text": expected,
                    "categories": ["english", "table"],
                }
            ]
        }
        report = evaluate_predictions(
            manifest,
            predictions(
                [
                    {
                        "fixture_id": "table",
                        "text": (
                            "| Code | Count | Total |\n"
                            "| --- | ---: | ---: |\n"
                            "| P-12 | 3 | 15.00 |\n"
                            "| Q-07 | 2 | 8.00 |\n"
                            "| R-99 | 100 | 999.00 |"
                        ),
                    }
                ]
            ),
        )

        self.assertEqual(report["metrics"]["table_fidelity"]["value"], 0)

    def test_latex_formula_is_scored_against_its_display_transcription(self):
        manifest = {
            "fixtures": [
                {
                    "id": "formula",
                    "gold_text": "Area under curve\n∫_0^1 x^2 dx = 1/3",
                    "formula_text": "∫_0^1 x^2 dx = 1/3",
                    "categories": ["english", "formula"],
                }
            ]
        }
        for output_format in ("latex", "markdown"):
            with self.subTest(output_format=output_format):
                input_data = predictions(
                    [
                        {
                            "fixture_id": "formula",
                            "text": r"Area under curve $\int_0^1 x^2\,dx = \frac{1}{3}$",
                        }
                    ]
                )
                input_data["run"]["output_format"] = output_format
                report = evaluate_predictions(manifest, input_data)

                self.assertEqual(report["run"]["output_format"], output_format)
                self.assertEqual(report["metrics"]["formula_fidelity"]["value"], 1)

    def test_perfect_predictions_score_each_metric(self):
        report = evaluate_predictions(
            small_manifest(),
            predictions(
                [
                    {
                        "fixture_id": "ordered-lines",
                        "text": "AB",
                        "elapsed_ms": 10,
                        "returned_tokens": 2,
                    },
                    {
                        "fixture_id": "formula",
                        "text": "\u00e9",
                        "elapsed_ms": 20,
                        "returned_tokens": 3,
                    },
                    {
                        "fixture_id": "table",
                        "text": "xy",
                        "elapsed_ms": 30,
                        "returned_tokens": 4,
                    },
                    {
                        "fixture_id": "blank",
                        "text": "",
                        "elapsed_ms": 40,
                        "returned_tokens": 0,
                    },
                ]
            ),
        )

        metrics = report["metrics"]
        self.assertEqual(metrics["character_error_rate"]["value"], 0)
        self.assertEqual(metrics["page_omission_rate"]["value"], 0)
        self.assertEqual(metrics["reading_order_score"]["value"], 1)
        self.assertEqual(metrics["table_fidelity"]["value"], 1)
        self.assertEqual(metrics["formula_fidelity"]["value"], 1)
        self.assertEqual(metrics["elapsed_time_ms"]["total_ms"], 100)
        self.assertEqual(metrics["elapsed_time_ms"]["mean_ms"], 25)
        self.assertEqual(metrics["returned_tokens"]["total"], 9)
        self.assertEqual(metrics["returned_tokens"]["mean"], 9 / 4)

    def test_errors_omissions_and_missing_live_fields_remain_visible(self):
        report = evaluate_predictions(
            small_manifest(),
            predictions(
                [
                    {
                        "fixture_id": "ordered-lines",
                        "text": "BA",
                        "elapsed_ms": 100,
                        "returned_tokens": 12,
                    },
                    {
                        "fixture_id": "formula",
                        "text": None,
                        "elapsed_ms": 40,
                        "returned_tokens": 8,
                    },
                    {
                        "fixture_id": "table",
                        "text": "xz",
                        "elapsed_ms": 30,
                        "returned_tokens": 4,
                    },
                    {
                        "fixture_id": "blank",
                        "text": "",
                        "elapsed_ms": None,
                        "returned_tokens": None,
                    },
                ]
            ),
        )

        metrics = report["metrics"]
        self.assertAlmostEqual(metrics["character_error_rate"]["value"], 4 / 5)
        self.assertAlmostEqual(metrics["page_omission_rate"]["value"], 1 / 4)
        self.assertEqual(metrics["reading_order_score"]["value"], 0)
        self.assertEqual(metrics["table_fidelity"]["value"], 0)
        self.assertIsNone(metrics["formula_fidelity"]["value"])
        self.assertEqual(metrics["formula_fidelity"]["pending"], 1)
        self.assertIsNone(metrics["elapsed_time_ms"]["total_ms"])
        self.assertEqual(metrics["elapsed_time_ms"]["pending_pages"], 1)
        self.assertIsNone(metrics["returned_tokens"]["total"])
        self.assertEqual(metrics["returned_tokens"]["pending_pages"], 1)

    def test_comparison_labels_measured_quality_regressions(self):
        baseline = evaluate_predictions(
            small_manifest(),
            predictions(
                [
                    {
                        "fixture_id": "ordered-lines",
                        "text": "AB",
                        "elapsed_ms": 10,
                        "returned_tokens": 2,
                    },
                    {
                        "fixture_id": "formula",
                        "text": "\u00e9",
                        "elapsed_ms": 20,
                        "returned_tokens": 3,
                    },
                    {
                        "fixture_id": "table",
                        "text": "xy",
                        "elapsed_ms": 30,
                        "returned_tokens": 4,
                    },
                    {
                        "fixture_id": "blank",
                        "text": "",
                        "elapsed_ms": 40,
                        "returned_tokens": 0,
                    },
                ]
            ),
        )
        candidate = evaluate_predictions(
            small_manifest(),
            predictions(
                [
                    {
                        "fixture_id": "ordered-lines",
                        "text": "BA",
                        "elapsed_ms": 100,
                        "returned_tokens": 12,
                    },
                    {
                        "fixture_id": "formula",
                        "text": None,
                        "elapsed_ms": 40,
                        "returned_tokens": 8,
                    },
                    {
                        "fixture_id": "table",
                        "text": "xz",
                        "elapsed_ms": 30,
                        "returned_tokens": 4,
                    },
                    {
                        "fixture_id": "blank",
                        "text": "",
                        "elapsed_ms": None,
                        "returned_tokens": None,
                    },
                ]
            ),
        )

        comparison = compare_reports(baseline, candidate)
        self.assertEqual(
            {
                name
                for name, result in comparison.items()
                if result["status"] == "regression"
            },
            {
                "character_error_rate",
                "page_omission_rate",
                "reading_order_score",
                "table_fidelity",
            },
        )
        self.assertEqual(comparison["formula_fidelity"]["status"], "pending")

    def test_cli_comparison_status_is_pending_when_candidate_metrics_are_pending(
        self,
    ):
        baseline = predictions(
            [
                {
                    "fixture_id": "ordered-lines",
                    "text": "AB",
                    "elapsed_ms": 1,
                    "returned_tokens": 2,
                },
                {
                    "fixture_id": "formula",
                    "text": "é",
                    "elapsed_ms": 1,
                    "returned_tokens": 1,
                },
                {
                    "fixture_id": "table",
                    "text": "xy",
                    "elapsed_ms": 1,
                    "returned_tokens": 1,
                },
                {
                    "fixture_id": "blank",
                    "text": "",
                    "elapsed_ms": 1,
                    "returned_tokens": 0,
                },
            ]
        )
        candidate = predictions(
            [
                {
                    "fixture_id": "ordered-lines",
                    "text": "AB",
                    "elapsed_ms": 1,
                    "returned_tokens": 2,
                },
                {
                    "fixture_id": "formula",
                    "text": "é",
                    "elapsed_ms": 1,
                    "returned_tokens": 1,
                },
                {
                    "fixture_id": "table",
                    "text": "xy",
                    "elapsed_ms": 1,
                    "returned_tokens": None,
                },
                {
                    "fixture_id": "blank",
                    "text": "",
                    "elapsed_ms": 1,
                    "returned_tokens": 0,
                },
            ]
        )

        with TemporaryDirectory() as directory:
            directory_path = Path(directory)
            manifest_path = directory_path / "manifest.json"
            baseline_path = directory_path / "baseline.json"
            candidate_path = directory_path / "candidate.json"
            manifest_path.write_text(json.dumps(small_manifest()), encoding="utf-8")
            baseline_path.write_text(json.dumps(baseline), encoding="utf-8")
            candidate_path.write_text(json.dumps(candidate), encoding="utf-8")
            output = StringIO()
            with redirect_stdout(output):
                exit_code = main(
                    [
                        "--manifest",
                        str(manifest_path),
                        "--baseline",
                        str(baseline_path),
                        "--predictions",
                        str(candidate_path),
                    ]
                )

        report = json.loads(output.getvalue())
        self.assertEqual(exit_code, 0)
        self.assertEqual(report["candidate"]["status"], "pending")
        self.assertEqual(
            report["comparison"]["returned_tokens"]["status"], "pending"
        )
        self.assertEqual(report["status"], "pending")

    def test_checked_in_fixture_manifest_and_pngs_are_complete(self):
        summary = verify_fixtures(ROOT / "manifest.json")

        self.assertGreaterEqual(summary["fixture_count"], 20)
        self.assertTrue(
            {
                "chinese",
                "english",
                "dense_small_text",
                "rotated",
                "multi_column",
                "table",
                "formula",
                "blank",
                "low_contrast",
            }.issubset(summary["categories"])
        )


if __name__ == "__main__":
    unittest.main()
