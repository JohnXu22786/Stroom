import json
import unittest
from contextlib import redirect_stderr, redirect_stdout
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
    def test_cli_reports_invalid_utf8_prediction_without_traceback(self):
        with TemporaryDirectory() as directory:
            root = Path(directory)
            manifest_path = root / "manifest.json"
            predictions_path = root / "predictions.json"
            manifest_path.write_text(json.dumps(small_manifest()), encoding="utf-8")
            predictions_path.write_bytes(b"\xff")

            stderr = StringIO()
            with redirect_stderr(stderr):
                exit_code = main(
                    [
                        "--manifest",
                        str(manifest_path),
                        "--predictions",
                        str(predictions_path),
                    ]
                )

        self.assertEqual(exit_code, 2)
        self.assertIn("evaluation error: cannot read", stderr.getvalue())
        self.assertNotIn("Traceback", stderr.getvalue())

    def test_cli_reports_invalid_utf8_fixture_manifest_without_traceback(self):
        with TemporaryDirectory() as directory:
            manifest_path = Path(directory) / "manifest.json"
            manifest_path.write_bytes(b"\xff")

            stderr = StringIO()
            with redirect_stderr(stderr):
                exit_code = main(
                    ["--manifest", str(manifest_path), "--verify-fixtures"]
                )

        self.assertEqual(exit_code, 2)
        self.assertIn(
            "evaluation error: cannot read fixture manifest", stderr.getvalue()
        )
        self.assertNotIn("Traceback", stderr.getvalue())

    def test_credential_like_setting_names_are_rejected(self):
        for key in (
            "api_token",
            "token_value",
            "tokenValue",
            "token_response",
            "api_tokens",
            "oauth_tokens",
            "session_tokens",
            "access_tokens",
            "refresh_tokens",
            "access_token_value",
            "accessTokenValue",
            "key",
            "KEY",
            "session_key",
            "signing_key",
            "authorization_header",
            "auth_header",
            "x-auth",
            "access_key",
            "private_key",
            "openAIKey",
            "OpenAIKey",
            "openAIKey2",
            "APIKey",
            "password",
            "passwd",
            "passphrase",
            "passcode",
            "bearer",
            "cookie",
            "session_cookie",
            "SESSION.Cookie",
            "cookieHeader",
            "stripe_key",
            "service_key",
            "stripeKey",
        ):
            with self.subTest(key=key):
                input_data = predictions([])
                input_data["run"]["settings"] = {key: "redacted-test-value"}
                with self.assertRaises(EvaluationError):
                    evaluate_predictions(small_manifest(), input_data)

    def test_credential_like_setting_key_is_not_echoed_to_stderr(self):
        secret_value = "actual-secret"
        secret_key = f"token={secret_value}"
        with TemporaryDirectory() as directory:
            root = Path(directory)
            manifest_path = root / "manifest.json"
            predictions_path = root / "predictions.json"
            manifest_path.write_text(json.dumps(small_manifest()), encoding="utf-8")
            input_data = predictions([])
            input_data["run"]["settings"] = {secret_key: 1}
            predictions_path.write_text(json.dumps(input_data), encoding="utf-8")

            stderr = StringIO()
            with redirect_stderr(stderr):
                exit_code = main(
                    [
                        "--manifest",
                        str(manifest_path),
                        "--predictions",
                        str(predictions_path),
                    ]
                )

        self.assertEqual(exit_code, 2)
        self.assertNotIn(secret_key, stderr.getvalue())
        self.assertNotIn(secret_value, stderr.getvalue())
        self.assertIn("credential-like field name", stderr.getvalue())

    def test_safe_run_settings_are_retained(self):
        input_data = predictions([])
        input_data["run"]["settings"] = {
            "temperature": 0.2,
            "region": "test-region",
            "endpoint": "https://host.example/?region=west",
            "monkey": "ordinary-word",
            "token_budget": 8192,
            "max_tokens": 2048,
        }

        report = evaluate_predictions(small_manifest(), input_data)

        self.assertEqual(report["run"]["settings"], input_data["run"]["settings"])

    def test_credential_like_setting_values_are_rejected(self):
        for value in (
            "https://host.example/?token=redacted-test-value",
            "Authorization: Bearer test-placeholder",
            "https://user:password@example.test/path",
        ):
            with self.subTest(value=value):
                input_data = predictions([])
                input_data["run"]["settings"] = {"endpoint": value}
                with self.assertRaises(EvaluationError):
                    evaluate_predictions(small_manifest(), input_data)

    def test_model_id_rejects_credential_like_values(self):
        for model_id in (
            "provider/model?token=redacted-test-value",
        ):
            with self.subTest(model_id=model_id):
                input_data = predictions([])
                input_data["run"]["model_id"] = model_id

                with self.assertRaises(EvaluationError):
                    evaluate_predictions(small_manifest(), input_data)

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

    def test_table_fidelity_preserves_trailing_empty_cells(self):
        expected = "A | B\nx |"
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

        def report_for(actual):
            return evaluate_predictions(
                manifest,
                predictions(
                    [
                        {
                            "fixture_id": "table",
                            "text": actual,
                        }
                    ]
                ),
            )

        missing_cell = report_for(
            "| A | B |\n| --- | --- |\n| x |"
        )
        preserved_empty_cell = report_for(
            "| A | B |\n| --- | --- |\n| x | |"
        )

        self.assertEqual(missing_cell["metrics"]["table_fidelity"]["value"], 0)
        self.assertEqual(
            preserved_empty_cell["metrics"]["table_fidelity"]["value"], 1
        )

    def test_table_fidelity_ignores_unmatched_trailing_frame_pipes(self):
        expected = "A | B |\nx | y |"
        report = evaluate_predictions(
            {
                "fixtures": [
                    {
                        "id": "table",
                        "gold_text": expected,
                        "table_text": expected,
                        "categories": ["english", "table"],
                    }
                ]
            },
            predictions(
                [
                    {
                        "fixture_id": "table",
                        "text": "| A | B |\n| --- | --- |\n| x | y |",
                    }
                ]
            ),
        )

        self.assertEqual(report["metrics"]["table_fidelity"]["value"], 1)

    def test_plain_text_tsv_table_scores_table_fidelity(self):
        expected = "Code | Count\nP-12 | 3"
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

        def report_for(actual):
            input_data = predictions([{"fixture_id": "table", "text": actual}])
            input_data["run"]["output_format"] = "plain_text"
            return evaluate_predictions(manifest, input_data)

        complete_table = report_for("Code\tCount\nP-12\t3")
        missing_cell = report_for("Code\tCount\nP-12")

        self.assertEqual(complete_table["metrics"]["table_fidelity"]["value"], 1)
        self.assertEqual(missing_cell["metrics"]["table_fidelity"]["value"], 0)

    def test_markdown_formatting_does_not_inflate_character_error_rate(self):
        manifest = {
            "fixtures": [
                {
                    "id": "markdown-table",
                    "gold_text": "Inventory\nCode Count\nP-12 3",
                    "categories": ["english", "table"],
                }
            ]
        }
        input_data = predictions(
            [
                {
                    "fixture_id": "markdown-table",
                    "text": (
                        "# Inventory\n"
                        "| Code | Count |\n"
                        "| --- | ---: |\n"
                        "| P-12 | 3 |"
                    ),
                }
            ]
        )
        input_data["run"]["output_format"] = "markdown"

        report = evaluate_predictions(manifest, input_data)

        self.assertEqual(report["metrics"]["character_error_rate"]["value"], 0)

    def test_markdown_table_from_manifest_does_not_inflate_character_error_rate(self):
        manifest = json.loads((ROOT / "manifest.json").read_text())
        fixture = next(
            fixture
            for fixture in manifest["fixtures"]
            if fixture["id"] == "table-en-01"
        )
        input_data = predictions(
            [
                {
                    "fixture_id": "table-en-01",
                    "text": (
                        "Synthetic Order\n"
                        "| Code | Count | Total |\n"
                        "| --- | ---: | ---: |\n"
                        "| P-12 | 3 | 15.00 |\n"
                        "| Q-07 | 2 | 8.00 |"
                    ),
                }
            ]
        )
        input_data["run"]["output_format"] = "markdown"

        report = evaluate_predictions({"fixtures": [fixture]}, input_data)

        self.assertEqual(report["metrics"]["character_error_rate"]["value"], 0)

    def test_plain_text_table_from_manifest_ignores_annotation_separators(self):
        manifest = json.loads((ROOT / "manifest.json").read_text())
        fixture = next(
            fixture
            for fixture in manifest["fixtures"]
            if fixture["id"] == "table-en-01"
        )
        input_data = predictions(
            [
                {
                    "fixture_id": "table-en-01",
                    "text": (
                        "Synthetic Order\n"
                        "Code Count Total\n"
                        "P-12 3 15.00\n"
                        "Q-07 2 8.00"
                    ),
                }
            ]
        )
        input_data["run"]["output_format"] = "plain_text"

        report = evaluate_predictions({"fixtures": [fixture]}, input_data)

        self.assertEqual(report["metrics"]["character_error_rate"]["value"], 0)

    def test_markdown_cer_keeps_literal_math_bars_outside_tables(self):
        manifest = {
            "fixtures": [
                {
                    "id": "absolute-value",
                    "gold_text": "The absolute value is |x|.",
                    "categories": ["english", "formula"],
                }
            ]
        }
        input_data = predictions(
            [{"fixture_id": "absolute-value", "text": "The absolute value is x."}]
        )
        input_data["run"]["output_format"] = "markdown"

        report = evaluate_predictions(manifest, input_data)

        self.assertGreater(report["metrics"]["character_error_rate"]["value"], 0)

    def test_markdown_cer_keeps_intraword_underscores(self):
        manifest = {
            "fixtures": [
                {
                    "id": "identifier",
                    "gold_text": "x_y_z",
                    "categories": ["english"],
                }
            ]
        }
        input_data = predictions([{"fixture_id": "identifier", "text": "xyz"}])
        input_data["run"]["output_format"] = "markdown"

        report = evaluate_predictions(manifest, input_data)

        self.assertGreater(report["metrics"]["character_error_rate"]["value"], 0)

    def test_markdown_escaped_underscores_are_literal(self):
        manifest = {
            "fixtures": [
                {
                    "id": "escaped-markdown-underscore",
                    "gold_text": "_x_",
                    "formula_text": "_x_",
                    "categories": ["english", "formula"],
                }
            ]
        }
        input_data = predictions(
            [
                {
                    "fixture_id": "escaped-markdown-underscore",
                    "text": r"\_x\_",
                }
            ]
        )
        input_data["run"]["output_format"] = "markdown"

        report = evaluate_predictions(manifest, input_data)

        self.assertEqual(report["metrics"]["character_error_rate"]["value"], 0)
        self.assertEqual(report["metrics"]["formula_fidelity"]["value"], 1)

    def test_currency_symbol_is_not_removed_as_a_math_delimiter(self):
        manifest = {
            "fixtures": [
                {
                    "id": "currency",
                    "gold_text": "Prices: $12 and $15",
                    "categories": ["english"],
                }
            ]
        }
        input_data = predictions(
            [{"fixture_id": "currency", "text": "Prices: 12 and 15"}]
        )
        input_data["run"]["output_format"] = "markdown"

        report = evaluate_predictions(manifest, input_data)

        self.assertGreater(report["metrics"]["character_error_rate"]["value"], 0)

    def test_latex_cer_strips_inline_math_next_to_cjk_text(self):
        manifest = {
            "fixtures": [
                {
                    "id": "cjk-inline-formula",
                    "gold_text": "令 x=1 时",
                    "formula_text": "x=1",
                    "categories": ["mixed_language", "formula"],
                }
            ]
        }
        input_data = predictions(
            [{"fixture_id": "cjk-inline-formula", "text": "令 $x=1$时"}]
        )
        input_data["run"]["output_format"] = "latex"

        report = evaluate_predictions(manifest, input_data)

        self.assertEqual(report["metrics"]["character_error_rate"]["value"], 0)
        self.assertEqual(report["metrics"]["formula_fidelity"]["value"], 1)

    def test_latex_cer_preserves_unmatched_currency_marker_before_cjk(self):
        manifest = {
            "fixtures": [
                {
                    "id": "cjk-currency",
                    "gold_text": "价格 $12元",
                    "categories": ["mixed_language"],
                }
            ]
        }
        input_data = predictions(
            [{"fixture_id": "cjk-currency", "text": "价格 12元"}]
        )
        input_data["run"]["output_format"] = "latex"

        report = evaluate_predictions(manifest, input_data)

        self.assertGreater(report["metrics"]["character_error_rate"]["value"], 0)

    def test_latex_escaped_display_symbols_match_literal_text(self):
        cases = (
            ("50%", r"50\%"),
            ("$50", r"\$50"),
            ("a_b", r"a\_b"),
            ("A&B", r"A\&B"),
            ("#tag", r"\#tag"),
            ("{x}", r"\{x\}"),
        )
        for expected, prediction in cases:
            with self.subTest(expected=expected):
                manifest = {
                    "fixtures": [
                        {
                            "id": "escaped-latex-symbol",
                            "gold_text": expected,
                            "formula_text": expected,
                            "categories": ["formula"],
                        }
                    ]
                }
                input_data = predictions(
                    [
                        {
                            "fixture_id": "escaped-latex-symbol",
                            "text": prediction,
                        }
                    ]
                )
                input_data["run"]["output_format"] = "latex"

                report = evaluate_predictions(manifest, input_data)

                self.assertEqual(
                    report["metrics"]["character_error_rate"]["value"], 0
                )
                self.assertEqual(
                    report["metrics"]["formula_fidelity"]["value"], 1
                )

    def test_latex_cer_ignores_optional_formula_spacing(self):
        formula = "∫_0^1 x^2 dx = 1/3"
        manifest = {
            "fixtures": [
                {
                    "id": "spacing-formula",
                    "gold_text": f"Integral\n{formula}",
                    "formula_text": formula,
                    "categories": ["english", "formula"],
                }
            ]
        }
        input_data = predictions(
            [
                {
                    "fixture_id": "spacing-formula",
                    "text": r"Integral $\int_0^1x^2dx=\frac{1}{3}$",
                }
            ]
        )
        input_data["run"]["output_format"] = "latex"

        report = evaluate_predictions(manifest, input_data)

        self.assertEqual(report["metrics"]["formula_fidelity"]["value"], 1)
        self.assertEqual(report["metrics"]["character_error_rate"]["value"], 0)

    def test_latex_delimiters_before_unicode_punctuation_are_removed(self):
        manifest = {
            "fixtures": [
                {
                    "id": "unicode-punctuation-formula",
                    "gold_text": "A = πr^2，",
                    "formula_text": "A = πr^2",
                    "categories": ["chinese", "formula"],
                }
            ]
        }
        input_data = predictions(
            [
                {
                    "fixture_id": "unicode-punctuation-formula",
                    "text": r"A = $\pi r^2$，",
                }
            ]
        )
        input_data["run"]["output_format"] = "latex"

        report = evaluate_predictions(manifest, input_data)

        self.assertEqual(report["metrics"]["formula_fidelity"]["value"], 1)
        self.assertEqual(report["metrics"]["character_error_rate"]["value"], 0)

    def test_plain_text_and_table_cer_ignore_formula_spacing(self):
        formula = "x^2 + y^2 = 1"
        manifest = {
            "fixtures": [
                {
                    "id": "plain-formula-spacing",
                    "gold_text": f"Equation\n{formula}",
                    "formula_text": formula,
                    "categories": ["english", "formula"],
                }
            ]
        }
        for output_format in ("plain_text", "table"):
            with self.subTest(output_format=output_format):
                input_data = predictions(
                    [
                        {
                            "fixture_id": "plain-formula-spacing",
                            "text": "Equation\nx^2+y^2=1",
                        }
                    ]
                )
                input_data["run"]["output_format"] = output_format

                report = evaluate_predictions(manifest, input_data)

                self.assertEqual(report["metrics"]["formula_fidelity"]["value"], 1)
                self.assertEqual(report["metrics"]["character_error_rate"]["value"], 0)

    def test_plain_text_cer_normalizes_markdown_table_rows_by_shape(self):
        expected = "Code | Count | Total\nP-12 | 3 | 15.00"
        gold_text = f"{expected}\nAbsolute value: |x| = 2"
        manifest = {
            "fixtures": [
                {
                    "id": "table-cer-row-shape",
                    "gold_text": gold_text,
                    "table_text": expected,
                    "formula_text": "|x| = 2",
                    "categories": ["english", "table"],
                }
            ]
        }
        input_data = predictions(
            [
                {
                    "fixture_id": "table-cer-row-shape",
                    "text": (
                        "| Code | Count | Total |\n"
                        "| --- | --- | --- |\n"
                        "| P-12 | 4 | 15.00 |\n"
                        "Absolute value: |x| = 2"
                    ),
                }
            ]
        )
        input_data["run"]["output_format"] = "plain_text"

        report = evaluate_predictions(manifest, input_data)

        self.assertEqual(
            report["metrics"]["character_error_rate"]["edit_distance"], 1
        )
        self.assertEqual(
            report["metrics"]["character_error_rate"]["reference_characters"],
            len("Code Count Total P-12 3 15.00 Absolute value: |x|=2"),
        )
        self.assertEqual(report["metrics"]["table_fidelity"]["value"], 0)

    def test_plain_text_cer_does_not_count_pipes_for_a_wrong_table_cell(self):
        expected = "Code | Count\nP-12 | 3"
        manifest = {
            "fixtures": [
                {
                    "id": "table-cer-cell-typo",
                    "gold_text": expected,
                    "table_text": expected,
                    "categories": ["english", "table"],
                }
            ]
        }
        input_data = predictions(
            [
                {
                    "fixture_id": "table-cer-cell-typo",
                    "text": "Code | Count\nP-12 | 4",
                }
            ]
        )
        input_data["run"]["output_format"] = "plain_text"

        report = evaluate_predictions(manifest, input_data)

        self.assertEqual(
            report["metrics"]["character_error_rate"]["edit_distance"], 1
        )
        self.assertEqual(
            report["metrics"]["character_error_rate"]["reference_characters"],
            len("Code Count P-12 3"),
        )

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
        for output_format, text in (
            (
                "markdown",
                "| Code | Count | Total |\n"
                "| --- | ---: | ---: |\n"
                "| P-12 | 3 | 15.00 |\n"
                "| Q-07 | 2 | 8.00 |\n"
                "| R-99 | 100 | 999.00 |",
            ),
            (
                "plain_text",
                "Code | Count | Total\n"
                "P-12 | 3 | 15.00\n"
                "Q-07 | 2 | 8.00\n"
                "R-99 | 100 | 999.00",
            ),
        ):
            with self.subTest(output_format=output_format):
                input_data = predictions(
                    [{"fixture_id": "table", "text": text}]
                )
                input_data["run"]["output_format"] = output_format
                report = evaluate_predictions(manifest, input_data)

                self.assertEqual(
                    report["metrics"]["table_fidelity"]["value"], 0
                )

    def test_inline_math_pipe_in_prose_does_not_reduce_table_fidelity(self):
        table = "Code | Count\nP-12 | 3"
        manifest = {
            "fixtures": [
                {
                    "id": "table-with-prose-formula",
                    "gold_text": f"{table}\nAbsolute value: |x| = 2",
                    "table_text": table,
                    "categories": ["english", "table", "formula"],
                    "formula_text": "|x| = 2",
                }
            ]
        }
        input_data = predictions(
            [
                {
                    "fixture_id": "table-with-prose-formula",
                    "text": (
                        "| Code | Count |\n"
                        "| --- | ---: |\n"
                        "| P-12 | 3 |\n"
                        "Absolute value: |x| = 2"
                    ),
                }
            ]
        )
        input_data["run"]["output_format"] = "markdown"

        report = evaluate_predictions(manifest, input_data)

        self.assertEqual(report["metrics"]["table_fidelity"]["value"], 1)

    def test_spaced_pipe_in_prose_after_table_does_not_reduce_fidelity(self):
        table = "Code | Count\nP-12 | 3"
        manifest = {
            "fixtures": [
                {
                    "id": "table-with-pipe-prose",
                    "gold_text": f"{table}\nSet relation: x | y",
                    "table_text": table,
                    "categories": ["english", "table"],
                }
            ]
        }
        for output_format, prediction in (
            (
                "markdown",
                "| Code | Count |\n"
                "| --- | --- |\n"
                "| P-12 | 3 |\n"
                "Set relation: x | y",
            ),
            (
                "plain_text",
                "Code | Count\nP-12 | 3\nSet relation: x | y",
            ),
        ):
            with self.subTest(output_format=output_format):
                input_data = predictions(
                    [
                        {
                            "fixture_id": "table-with-pipe-prose",
                            "text": prediction,
                        }
                    ]
                )
                input_data["run"]["output_format"] = output_format

                report = evaluate_predictions(manifest, input_data)

                self.assertEqual(
                    report["metrics"]["table_fidelity"]["value"], 1
                )

    def test_one_word_label_in_pipe_prose_after_table_does_not_reduce_fidelity(self):
        table = "Code | Count\nP-12 | 3"
        manifest = {
            "fixtures": [
                {
                    "id": "table-with-one-word-label",
                    "gold_text": f"{table}\nNote: x | y",
                    "table_text": table,
                    "categories": ["english", "table"],
                }
            ]
        }
        input_data = predictions(
            [
                {
                    "fixture_id": "table-with-one-word-label",
                    "text": f"{table}\nNote: x | y",
                }
            ]
        )
        input_data["run"]["output_format"] = "plain_text"

        report = evaluate_predictions(manifest, input_data)

        self.assertEqual(report["metrics"]["table_fidelity"]["value"], 1)

    def test_table_fidelity_accepts_compact_rows_without_outer_pipes(self):
        table = "Code|Count\nP-12|3"
        manifest = {
            "fixtures": [
                {
                    "id": "compact-table",
                    "gold_text": table,
                    "table_text": table,
                    "categories": ["english", "table"],
                }
            ]
        }
        input_data = predictions(
            [{"fixture_id": "compact-table", "text": table}]
        )
        input_data["run"]["output_format"] = "markdown"

        report = evaluate_predictions(manifest, input_data)

        self.assertEqual(report["metrics"]["table_fidelity"]["value"], 1)

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
                self.assertEqual(
                    report["metrics"]["character_error_rate"]["value"], 0
                )

    def test_latex_square_root_is_scored_against_its_display_transcription(self):
        manifest = {
            "fixtures": [
                {
                    "id": "square-root",
                    "gold_text": "Square root of x\n√x",
                    "formula_text": "√x",
                    "categories": ["english", "formula"],
                }
            ]
        }
        input_data = predictions(
            [{"fixture_id": "square-root", "text": r"Square root of x $\sqrt{x}$"}]
        )
        input_data["run"]["output_format"] = "latex"

        report = evaluate_predictions(manifest, input_data)

        self.assertEqual(report["metrics"]["formula_fidelity"]["value"], 1)
        self.assertEqual(report["metrics"]["character_error_rate"]["value"], 0)

    def test_latex_compound_square_root_preserves_operand_grouping(self):
        formula = "√(x+1)"
        manifest = {
            "fixtures": [
                {
                    "id": "compound-square-root",
                    "gold_text": formula,
                    "formula_text": formula,
                    "categories": ["formula"],
                }
            ]
        }
        input_data = predictions(
            [{"fixture_id": "compound-square-root", "text": r"$\sqrt{x+1}$"}]
        )
        input_data["run"]["output_format"] = "latex"

        report = evaluate_predictions(manifest, input_data)

        self.assertEqual(report["metrics"]["formula_fidelity"]["value"], 1)
        self.assertEqual(report["metrics"]["character_error_rate"]["value"], 0)

    def test_nested_square_root_fraction_is_scored_against_its_display_text(self):
        manifest = {
            "fixtures": [
                {
                    "id": "nested-radical-fraction",
                    "gold_text": "√x/2",
                    "formula_text": "√x/2",
                    "categories": ["formula"],
                }
            ]
        }
        input_data = predictions(
            [
                {
                    "fixture_id": "nested-radical-fraction",
                    "text": r"$\frac{\sqrt{x}}{2}$",
                }
            ]
        )
        input_data["run"]["output_format"] = "latex"

        report = evaluate_predictions(manifest, input_data)

        self.assertEqual(report["metrics"]["formula_fidelity"]["value"], 1)
        self.assertEqual(report["metrics"]["character_error_rate"]["value"], 0)

    def test_latex_fraction_preserves_compound_operand_grouping(self):
        manifest = {
            "fixtures": [
                {
                    "id": "compound-fraction",
                    "gold_text": "(x+1)/2",
                    "formula_text": "(x+1)/2",
                    "categories": ["formula"],
                }
            ]
        }
        input_data = predictions(
            [{"fixture_id": "compound-fraction", "text": r"$\frac{x+1}{2}$"}]
        )
        input_data["run"]["output_format"] = "latex"

        report = evaluate_predictions(manifest, input_data)

        self.assertEqual(report["metrics"]["formula_fidelity"]["value"], 1)
        self.assertEqual(report["metrics"]["character_error_rate"]["value"], 0)

    def test_latex_fraction_groups_multiplication_in_denominator(self):
        for latex_operator, display_operator in (
            (r"\cdot ", "·"),
            (r"\times ", "×"),
        ):
            with self.subTest(latex_operator=latex_operator):
                gold_text = f"x/(a{display_operator}b)"
                manifest = {
                    "fixtures": [
                        {
                            "id": "fraction-product-denominator",
                            "gold_text": gold_text,
                            "formula_text": gold_text,
                            "categories": ["formula"],
                        }
                    ]
                }
                input_data = predictions(
                    [
                        {
                            "fixture_id": "fraction-product-denominator",
                            "text": rf"$\frac{{x}}{{a{latex_operator}b}}$",
                        }
                    ]
                )
                input_data["run"]["output_format"] = "latex"

                report = evaluate_predictions(manifest, input_data)

                self.assertEqual(report["metrics"]["formula_fidelity"]["value"], 1)
                self.assertEqual(report["metrics"]["character_error_rate"]["value"], 0)

    def test_latex_fraction_keeps_unary_negative_without_extra_grouping(self):
        manifest = {
            "fixtures": [
                {
                    "id": "negative-fraction",
                    "gold_text": "-1/2",
                    "formula_text": "-1/2",
                    "categories": ["formula"],
                }
            ]
        }
        input_data = predictions(
            [{"fixture_id": "negative-fraction", "text": r"$\frac{-1}{2}$"}]
        )
        input_data["run"]["output_format"] = "latex"

        report = evaluate_predictions(manifest, input_data)

        self.assertEqual(report["metrics"]["formula_fidelity"]["value"], 1)
        self.assertEqual(report["metrics"]["character_error_rate"]["value"], 0)

    def test_multi_digit_superscripts_match_latex_exponents(self):
        manifest = {
            "fixtures": [
                {
                    "id": "multi-digit-exponent",
                    "gold_text": "Power: x¹⁰",
                    "formula_text": "x¹⁰",
                    "categories": ["english", "formula"],
                }
            ]
        }
        input_data = predictions(
            [
                {
                    "fixture_id": "multi-digit-exponent",
                    "text": r"Power: $x^{10}$",
                }
            ]
        )
        input_data["run"]["output_format"] = "latex"

        report = evaluate_predictions(manifest, input_data)

        self.assertEqual(report["metrics"]["formula_fidelity"]["value"], 1)
        self.assertEqual(report["metrics"]["character_error_rate"]["value"], 0)

    def test_compound_latex_exponent_preserves_grouping(self):
        def evaluate(gold_text):
            manifest = {
                "fixtures": [
                    {
                        "id": "compound-exponent",
                        "gold_text": gold_text,
                        "formula_text": gold_text,
                        "categories": ["formula"],
                    }
                ]
            }
            input_data = predictions(
                [
                    {
                        "fixture_id": "compound-exponent",
                        "text": r"$x^{n+1}$",
                    }
                ]
            )
            input_data["run"]["output_format"] = "latex"
            return evaluate_predictions(manifest, input_data)

        equivalent = evaluate("x^(n+1)")
        different = evaluate("x^n+1")

        self.assertEqual(equivalent["metrics"]["formula_fidelity"]["value"], 1)
        self.assertEqual(equivalent["metrics"]["character_error_rate"]["value"], 0)
        self.assertEqual(different["metrics"]["formula_fidelity"]["value"], 0)
        self.assertGreater(different["metrics"]["character_error_rate"]["value"], 0)

    def test_plain_text_cer_normalizes_multi_digit_superscript_sequences(self):
        manifest = {
            "fixtures": [
                {
                    "id": "plain-text-exponent",
                    "gold_text": "Power: x¹⁰",
                    "formula_text": "x¹⁰",
                    "categories": ["english", "formula"],
                }
            ]
        }
        input_data = predictions(
            [{"fixture_id": "plain-text-exponent", "text": "Power: x^10"}]
        )
        input_data["run"]["output_format"] = "plain_text"

        report = evaluate_predictions(manifest, input_data)

        self.assertEqual(report["metrics"]["formula_fidelity"]["value"], 1)
        self.assertEqual(report["metrics"]["character_error_rate"]["value"], 0)

    def test_table_formula_metrics_normalize_latex_superscripts(self):
        manifest = {
            "fixtures": [
                {
                    "id": "table-formula-exponent",
                    "gold_text": "Power: x¹⁰",
                    "formula_text": "x¹⁰",
                    "categories": ["english", "formula"],
                }
            ]
        }
        input_data = predictions(
            [
                {
                    "fixture_id": "table-formula-exponent",
                    "text": r"Power: $x^{10}$",
                }
            ]
        )
        input_data["run"]["output_format"] = "table"

        report = evaluate_predictions(manifest, input_data)

        self.assertEqual(report["metrics"]["formula_fidelity"]["value"], 1)
        self.assertEqual(report["metrics"]["character_error_rate"]["value"], 0)

    def test_markdown_bold_formula_preserves_formula_fidelity(self):
        manifest = {
            "fixtures": [
                {
                    "id": "bold-formula",
                    "gold_text": "A = πr²",
                    "formula_text": "A = πr²",
                    "categories": ["english", "formula"],
                }
            ]
        }
        for output_format in ("markdown", "table"):
            with self.subTest(output_format=output_format):
                input_data = predictions(
                    [{"fixture_id": "bold-formula", "text": r"**A = \pi r^2**"}]
                )
                input_data["run"]["output_format"] = output_format

                report = evaluate_predictions(manifest, input_data)

                self.assertEqual(
                    report["metrics"]["formula_fidelity"]["value"], 1
                )

    def test_markdown_numbered_list_marker_preserves_formula_fidelity(self):
        manifest = {
            "fixtures": [
                {
                    "id": "numbered-list-formula",
                    "gold_text": "x = 1",
                    "formula_text": "x = 1",
                    "categories": ["english", "formula"],
                }
            ]
        }
        input_data = predictions(
            [{"fixture_id": "numbered-list-formula", "text": "1. x = 1"}]
        )
        input_data["run"]["output_format"] = "markdown"

        report = evaluate_predictions(manifest, input_data)

        self.assertEqual(report["metrics"]["character_error_rate"]["value"], 0)
        self.assertEqual(report["metrics"]["formula_fidelity"]["value"], 1)

    def test_plain_text_numbered_list_marker_preserves_formula_fidelity(self):
        manifest = {
            "fixtures": [
                {
                    "id": "plain-numbered-list-formula",
                    "gold_text": "x = 1",
                    "formula_text": "x = 1",
                    "categories": ["english", "formula"],
                }
            ]
        }
        input_data = predictions(
            [
                {
                    "fixture_id": "plain-numbered-list-formula",
                    "text": "1. x = 1",
                }
            ]
        )
        input_data["run"]["output_format"] = "plain_text"

        report = evaluate_predictions(manifest, input_data)

        self.assertEqual(report["metrics"]["formula_fidelity"]["value"], 1)

    def test_markdown_formula_strips_list_markers_from_each_line(self):
        manifest = {
            "fixtures": [
                {
                    "id": "multiline-list-formula",
                    "gold_text": "Intro\nx=1",
                    "formula_text": "x=1",
                    "categories": ["english", "formula"],
                }
            ]
        }
        input_data = predictions(
            [
                {
                    "fixture_id": "multiline-list-formula",
                    "text": "- Intro\n- x = 1",
                }
            ]
        )
        input_data["run"]["output_format"] = "markdown"

        report = evaluate_predictions(manifest, input_data)

        self.assertEqual(report["metrics"]["character_error_rate"]["value"], 0)
        self.assertEqual(report["metrics"]["formula_fidelity"]["value"], 1)

    def test_markdown_formula_strips_blockquote_markers(self):
        manifest = {
            "fixtures": [
                {
                    "id": "blockquote-formula",
                    "gold_text": "x = 1",
                    "formula_text": "x = 1",
                    "categories": ["english", "formula"],
                }
            ]
        }
        input_data = predictions(
            [{"fixture_id": "blockquote-formula", "text": "> x = 1"}]
        )
        input_data["run"]["output_format"] = "markdown"

        report = evaluate_predictions(manifest, input_data)

        self.assertEqual(report["metrics"]["character_error_rate"]["value"], 0)
        self.assertEqual(report["metrics"]["formula_fidelity"]["value"], 1)

    def test_markdown_math_multiplication_is_not_stripped_as_emphasis(self):
        formula = "2 * x * 3"
        manifest = {
            "fixtures": [
                {
                    "id": "multiplication-formula",
                    "gold_text": formula,
                    "formula_text": formula,
                    "categories": ["english", "formula"],
                }
            ]
        }
        input_data = predictions(
            [{"fixture_id": "multiplication-formula", "text": "2 x 3"}]
        )
        input_data["run"]["output_format"] = "markdown"

        report = evaluate_predictions(manifest, input_data)

        self.assertGreater(report["metrics"]["character_error_rate"]["value"], 0)
        self.assertEqual(report["metrics"]["formula_fidelity"]["value"], 0)

    def test_markdown_compact_multiplication_is_not_stripped_as_emphasis(self):
        formula = "2*3*4"
        manifest = {
            "fixtures": [
                {
                    "id": "compact-multiplication-formula",
                    "gold_text": formula,
                    "formula_text": formula,
                    "categories": ["formula"],
                }
            ]
        }
        for prediction in (formula, f"**{formula}**"):
            with self.subTest(prediction=prediction):
                input_data = predictions(
                    [
                        {
                            "fixture_id": "compact-multiplication-formula",
                            "text": prediction,
                        }
                    ]
                )
                input_data["run"]["output_format"] = "markdown"

                report = evaluate_predictions(manifest, input_data)

                self.assertEqual(
                    report["metrics"]["character_error_rate"]["value"], 0
                )
                self.assertEqual(
                    report["metrics"]["formula_fidelity"]["value"], 1
                )

    def test_markdown_formula_annotation_preserves_leading_unary_minus(self):
        formula = "- 1 = 2"
        manifest = {
            "fixtures": [
                {
                    "id": "negative-formula",
                    "gold_text": formula,
                    "formula_text": formula,
                    "categories": ["english", "formula"],
                }
            ]
        }
        input_data = predictions(
            [{"fixture_id": "negative-formula", "text": r"$-1 = 2$"}]
        )
        input_data["run"]["output_format"] = "markdown"

        report = evaluate_predictions(manifest, input_data)

        self.assertEqual(report["metrics"]["character_error_rate"]["value"], 0)
        self.assertEqual(report["metrics"]["formula_fidelity"]["value"], 1)

    def test_formula_fidelity_rejects_extra_operator_but_allows_prose_boundary(self):
        manifest = {
            "fixtures": [
                {
                    "id": "area-equation",
                    "gold_text": "A = πr²",
                    "formula_text": "A = πr²",
                    "categories": ["formula"],
                }
            ]
        }

        incorrect = predictions(
            [{"fixture_id": "area-equation", "text": "A = πr² + 1"}]
        )
        incorrect_report = evaluate_predictions(manifest, incorrect)

        prose = predictions(
            [
                {
                    "fixture_id": "area-equation",
                    "text": "Equation: A = πr². The radius is measured in centimeters.",
                }
            ]
        )
        prose_report = evaluate_predictions(manifest, prose)

        self.assertEqual(
            incorrect_report["metrics"]["formula_fidelity"]["value"], 0
        )
        self.assertEqual(prose_report["metrics"]["formula_fidelity"]["value"], 1)

    def test_formula_fidelity_rejects_equation_operator_before_formula_span(self):
        manifest = {
            "fixtures": [
                {
                    "id": "equation-fragment",
                    "gold_text": "x = 1",
                    "formula_text": "x = 1",
                    "categories": ["formula"],
                }
            ]
        }

        for operator in ("=", "<", ">", "≤", "≥"):
            with self.subTest(operator=operator):
                report = evaluate_predictions(
                    manifest,
                    predictions(
                        [
                            {
                                "fixture_id": "equation-fragment",
                                "text": f"-x {operator} x = 1",
                            }
                        ]
                    ),
                )

                self.assertEqual(
                    report["metrics"]["formula_fidelity"]["value"], 0
                )

    def test_formula_fidelity_allows_numbered_prose_before_formula(self):
        manifest = {
            "fixtures": [
                {
                    "id": "numbered-prose-formula",
                    "gold_text": "Question 1: x = 1",
                    "formula_text": "x = 1",
                    "categories": ["english", "formula"],
                }
            ]
        }
        for label in (
            "Question 1",
            "Question 1:",
            "Question 2.",
            "Question 3)",
            "Question 5,",
            "问题 4：",
            "问题 6、",
            "第1题",
        ):
            with self.subTest(label=label):
                input_data = predictions(
                    [
                        {
                            "fixture_id": "numbered-prose-formula",
                            "text": f"{label} x = 1",
                        }
                    ]
                )

                report = evaluate_predictions(manifest, input_data)

                self.assertEqual(
                    report["metrics"]["formula_fidelity"]["value"], 1
                )

    def test_formula_fidelity_allows_date_prose_before_formula(self):
        for date, punctuation in (
            ("2025-01-01", ","),
            ("01/02/2025", ","),
            ("2025/01/01", ""),
        ):
            with self.subTest(date=date, punctuation=punctuation):
                text = f"Date: {date}{punctuation} x=1"
                manifest = {
                    "fixtures": [
                        {
                            "id": "date-prose-formula",
                            "gold_text": text,
                            "formula_text": "x=1",
                            "categories": ["english", "formula"],
                        }
                    ]
                }
                input_data = predictions(
                    [{"fixture_id": "date-prose-formula", "text": text}]
                )

                report = evaluate_predictions(manifest, input_data)

                self.assertEqual(
                    report["metrics"]["character_error_rate"]["value"], 0
                )
                self.assertEqual(
                    report["metrics"]["formula_fidelity"]["value"], 1
                )

    def test_formula_fidelity_allows_contextual_date_after_formula(self):
        text = "x = 1 2025-01-01 is the date"
        manifest = {
            "fixtures": [
                {
                    "id": "date-after-formula",
                    "gold_text": text,
                    "formula_text": "x = 1",
                    "categories": ["english", "formula"],
                }
            ]
        }
        input_data = predictions(
            [{"fixture_id": "date-after-formula", "text": text}]
        )
        input_data["run"]["output_format"] = "plain_text"

        report = evaluate_predictions(manifest, input_data)

        self.assertEqual(report["metrics"]["character_error_rate"]["value"], 0)
        self.assertEqual(report["metrics"]["formula_fidelity"]["value"], 1)

    def test_formula_fidelity_allows_standalone_date_after_formula(self):
        manifest = {
            "fixtures": [
                {
                    "id": "standalone-date-after-formula",
                    "gold_text": "x = 1\n2025-01-01",
                    "formula_text": "x = 1",
                    "categories": ["english", "formula"],
                }
            ]
        }

        date_only = evaluate_predictions(
            manifest,
            predictions(
                [
                    {
                        "fixture_id": "standalone-date-after-formula",
                        "text": "x = 1\n2025-01-01",
                    }
                ]
            ),
        )
        date_with_operator = evaluate_predictions(
            manifest,
            predictions(
                [
                    {
                        "fixture_id": "standalone-date-after-formula",
                        "text": "x = 1\n2025-01-01 + 2",
                    }
                ]
            ),
        )

        self.assertEqual(date_only["metrics"]["formula_fidelity"]["value"], 1)
        self.assertEqual(
            date_with_operator["metrics"]["formula_fidelity"]["value"], 0
        )

    def test_formula_fidelity_allows_numbered_prose_after_formula(self):
        text = "x = 1 2 items remain"
        manifest = {
            "fixtures": [
                {
                    "id": "numbered-prose-after-formula",
                    "gold_text": text,
                    "formula_text": "x = 1",
                    "categories": ["english", "formula"],
                }
            ]
        }
        input_data = predictions(
            [{"fixture_id": "numbered-prose-after-formula", "text": text}]
        )

        report = evaluate_predictions(manifest, input_data)

        self.assertEqual(report["metrics"]["character_error_rate"]["value"], 0)
        self.assertEqual(report["metrics"]["formula_fidelity"]["value"], 1)

    def test_formula_fidelity_allows_decimal_measurement_after_formula(self):
        manifest = {
            "fixtures": [
                {
                    "id": "decimal-measurement-after-formula",
                    "gold_text": "x = 1\n2.5 cm",
                    "formula_text": "x = 1",
                    "categories": ["english", "formula"],
                }
            ]
        }

        measurement = evaluate_predictions(
            manifest,
            predictions(
                [
                    {
                        "fixture_id": "decimal-measurement-after-formula",
                        "text": "x = 1\n2.5 cm",
                    }
                ]
            ),
        )
        adjacent_number = evaluate_predictions(
            manifest,
            predictions(
                [
                    {
                        "fixture_id": "decimal-measurement-after-formula",
                        "text": "x = 1 2.5",
                    }
                ]
            ),
        )

        self.assertEqual(measurement["metrics"]["formula_fidelity"]["value"], 1)
        self.assertEqual(
            adjacent_number["metrics"]["formula_fidelity"]["value"], 0
        )

    def test_formula_fidelity_rejects_uncontextualized_number_before_formula(self):
        manifest = {
            "fixtures": [
                {
                    "id": "number-before-formula",
                    "gold_text": "x = 1",
                    "formula_text": "x = 1",
                    "categories": ["formula"],
                }
            ]
        }
        input_data = predictions(
            [
                {
                    "fixture_id": "number-before-formula",
                    "text": "2, x = 1",
                }
            ]
        )

        report = evaluate_predictions(manifest, input_data)

        self.assertEqual(report["metrics"]["formula_fidelity"]["value"], 0)

    def test_formula_fidelity_rejects_decimal_separator_continuation(self):
        manifest = {
            "fixtures": [
                {
                    "id": "decimal-exponent",
                    "gold_text": "A = πr²",
                    "formula_text": "A = πr²",
                    "categories": ["formula"],
                }
            ]
        }

        for separator in (".", ","):
            with self.subTest(separator=separator):
                report = evaluate_predictions(
                    manifest,
                    predictions(
                        [
                            {
                                "fixture_id": "decimal-exponent",
                                "text": f"A = πr^2{separator}5",
                            }
                        ]
                    ),
                )

                self.assertEqual(
                    report["metrics"]["formula_fidelity"]["value"], 0
                )

    def test_formula_fidelity_rejects_math_terms_across_whitespace(self):
        manifest = {
            "fixtures": [
                {
                    "id": "area-equation",
                    "gold_text": "A = πr²",
                    "formula_text": "A = πr²",
                    "categories": ["formula"],
                }
            ]
        }

        for text in (
            "2 A = πr²",
            "x A = πr²",
            "A = πr² 2",
            "A = πr² x",
            "A = πr² cos θ",
            "A = πr² 2025-01-01 + 2",
        ):
            with self.subTest(text=text):
                report = evaluate_predictions(
                    manifest,
                    predictions([{"fixture_id": "area-equation", "text": text}]),
                )

                self.assertEqual(
                    report["metrics"]["formula_fidelity"]["value"], 0
                )

    def test_formula_fidelity_rejects_latex_function_terms_across_whitespace(self):
        manifest = {
            "fixtures": [
                {
                    "id": "area-equation",
                    "gold_text": "A = πr²",
                    "formula_text": "A = πr²",
                    "categories": ["formula"],
                }
            ]
        }
        input_data = predictions(
            [
                {
                    "fixture_id": "area-equation",
                    "text": r"$A = \pi r^2 \cos \theta$",
                }
            ]
        )
        input_data["run"]["output_format"] = "latex"

        report = evaluate_predictions(manifest, input_data)

        self.assertEqual(report["metrics"]["formula_fidelity"]["value"], 0)

    def test_formula_fidelity_rejects_latex_greek_terms_across_whitespace(self):
        manifest = {
            "fixtures": [
                {
                    "id": "area-equation",
                    "gold_text": "A = πr²",
                    "formula_text": "A = πr²",
                    "categories": ["formula"],
                }
            ]
        }
        input_data = predictions(
            [
                {
                    "fixture_id": "area-equation",
                    "text": r"$A = \pi r^2 \theta$",
                }
            ]
        )
        input_data["run"]["output_format"] = "latex"

        report = evaluate_predictions(manifest, input_data)

        self.assertEqual(report["metrics"]["formula_fidelity"]["value"], 0)

    def test_formula_fidelity_rejects_latex_integral_operator_after_formula(self):
        manifest = {
            "fixtures": [
                {
                    "id": "area-equation",
                    "gold_text": "A = πr²",
                    "formula_text": "A = πr²",
                    "categories": ["formula"],
                }
            ]
        }
        input_data = predictions(
            [
                {
                    "fixture_id": "area-equation",
                    "text": r"A = $\pi r^2 \int$",
                }
            ]
        )
        input_data["run"]["output_format"] = "latex"

        report = evaluate_predictions(manifest, input_data)

        self.assertEqual(report["metrics"]["formula_fidelity"]["value"], 0)

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
