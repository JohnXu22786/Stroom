import unittest

from validate_pr_description import validate_pr_body


VALID_BODY = """## What this PR does
Adds a single Mint Glass startup screen.

### Before this PR:
The startup palette changed when migration ran.

### After this PR:
The startup screen always uses Mint Glass.

### Type of change
Bug fix, Documentation
"""


class ValidatePrDescriptionTest(unittest.TestCase):
    def test_accepts_required_sections_and_omitted_breaking_section(self):
        self.assertEqual(validate_pr_body(VALID_BODY), [])

    def test_accepts_a_filled_breaking_changes_section(self):
        body = VALID_BODY + "\n### Breaking changes (if any)\nRemoves an old API.\n"

        self.assertEqual(validate_pr_body(body), [])

    def test_rejects_missing_required_headings(self):
        errors = validate_pr_body("## What this PR does\nSummary.\n")

        self.assertTrue(any("Before this PR" in error for error in errors))
        self.assertTrue(any("Type of change" in error for error in errors))

    def test_does_not_accept_headings_inside_a_code_block(self):
        body = "```markdown\n" + VALID_BODY + "```\n"

        errors = validate_pr_body(body)

        self.assertTrue(any("Missing required heading" in error for error in errors))

    def test_html_pre_blocks_do_not_satisfy_required_sections(self):
        errors = validate_pr_body("<pre>\n" + VALID_BODY + "\n</pre>")

        self.assertTrue(any("Missing required heading" in error for error in errors))

    def test_unclosed_html_pre_block_is_rejected(self):
        errors = validate_pr_body("<pre>\n" + VALID_BODY)

        self.assertTrue(any("HTML <pre>" in error for error in errors))

    def test_fence_closers_must_match_the_opening_length_and_have_no_info(self):
        cases = (
            "````markdown\n```\n" + VALID_BODY + "````\n",
            "```markdown\n``` trailing text\n" + VALID_BODY + "```\n",
        )

        for body in cases:
            with self.subTest(body=body[:30]):
                errors = validate_pr_body(body)

                self.assertTrue(
                    any("Missing required heading" in error for error in errors)
                )

    def test_indented_headings_do_not_satisfy_required_sections(self):
        body = "\n".join(
            f"    {line}" if line.startswith("#") else line
            for line in VALID_BODY.splitlines()
        )

        errors = validate_pr_body(body)

        self.assertTrue(any("Missing required heading" in error for error in errors))

    def test_unclosed_comment_cannot_hide_missing_sections(self):
        errors = validate_pr_body("<!--\n" + VALID_BODY)

        self.assertTrue(any("Close every HTML comment" in error for error in errors))
        self.assertTrue(any("Missing required heading" in error for error in errors))

    def test_rejects_empty_sections_and_unfilled_type_placeholder(self):
        body = """## What this PR does
Summary.

### Before this PR:
<!-- Describe the previous behavior. -->

### After this PR:
Result.

### Type of change
[type]
"""

        errors = validate_pr_body(body)

        self.assertTrue(any("Before this PR:" in error for error in errors))
        self.assertTrue(any("placeholder" in error.lower() for error in errors))

    def test_rejects_placeholders_in_every_required_and_optional_section(self):
        cases = (
            VALID_BODY.replace("Adds a single Mint Glass startup screen.", "[summary]"),
            VALID_BODY.replace("Adds a single Mint Glass startup screen.", "[fill this in]"),
            VALID_BODY.replace(
                "The startup palette changed when migration ran.", "TODO"
            ),
            VALID_BODY.replace(
                "The startup screen always uses Mint Glass.", "[description]"
            ),
            VALID_BODY.replace("Bug fix, Documentation", "FIXME"),
            VALID_BODY + "\n### Breaking changes (if any)\nTBD\n",
            VALID_BODY.replace(
                "The startup screen always uses Mint Glass.",
                "The startup screen always uses Mint Glass.\nFixes #",
            ),
        )

        for body in cases:
            with self.subTest(body=body[-50:]):
                self.assertTrue(
                    any("placeholder" in error.lower() for error in validate_pr_body(body))
                )

    def test_rejects_unremoved_template_instruction_sentences(self):
        cases = (
            VALID_BODY.replace(
                "The startup palette changed when migration ran.",
                "Describe the behavior or state before these changes.",
            ),
            VALID_BODY.replace(
                "The startup screen always uses Mint Glass.",
                "Describe the resulting behavior or state.",
            ),
            VALID_BODY.replace(
                "Bug fix, Documentation",
                "Enter the applicable type, such as Bug fix, Feature, Documentation, "
                "Refactor, Performance, Test, CI/build, or Chore.",
            ),
            VALID_BODY
            + "\n### Breaking changes (if any)\n"
            + "Describe backwards-incompatible changes, or write None.\n",
        )

        for body in cases:
            with self.subTest(body=body[-80:]):
                self.assertTrue(
                    any(
                        "instruction" in error.lower()
                        for error in validate_pr_body(body)
                    )
                )

    def test_sanitized_fixes_instruction_is_still_rejected(self):
        body = VALID_BODY.replace(
            "The startup screen always uses Mint Glass.",
            "Add `Fixes #123` here only when this PR closes an issue.",
        )

        self.assertTrue(
            any("instruction" in error.lower() for error in validate_pr_body(body))
        )

    def test_does_not_treat_a_description_of_removed_todo_as_a_placeholder(self):
        body = VALID_BODY.replace(
            "The startup palette changed when migration ran.",
            "The startup palette removes an obsolete TODO marker.",
        )

        self.assertEqual(validate_pr_body(body), [])

    def test_inline_code_does_not_start_html_comments_or_count_as_placeholders(self):
        body = VALID_BODY.replace(
            "Adds a single Mint Glass startup screen.",
            "Adds a single Mint Glass startup screen with literal `<!--` and `[summary]` tokens.",
        )

        self.assertEqual(validate_pr_body(body), [])

    def test_rejects_non_latin_description_text(self):
        errors = validate_pr_body(VALID_BODY + "\n中文说明")

        self.assertTrue(any("English" in error for error in errors))

    def test_rejects_latin_script_non_english_narrative_and_breaking_sections(self):
        french_summary = VALID_BODY.replace(
            "Adds a single Mint Glass startup screen.",
            "La palette change après chaque démarrage.",
        )
        spanish_before = VALID_BODY.replace(
            "The startup palette changed when migration ran.",
            "El color cambia cuando se ejecuta una migración.",
        )
        german_after = VALID_BODY.replace(
            "The startup screen always uses Mint Glass.",
            "Die Startseite wird bei jeder Migration grün.",
        )
        french_breaking = (
            VALID_BODY
            + "\n### Breaking changes (if any)\n"
            + "La page de démarrage change après chaque migration.\n"
        )

        for body in (french_summary, spanish_before, german_after, french_breaking):
            with self.subTest(body=body[-70:]):
                self.assertTrue(
                    any("English" in error for error in validate_pr_body(body))
                )

    def test_english_cognates_are_not_mistaken_for_foreign_language(self):
        body = VALID_BODY.replace(
            "Adds a single Mint Glass startup screen.",
            "This page change affects startup behavior.",
        )

        self.assertEqual(validate_pr_body(body), [])

    def test_rejects_a_short_non_english_description(self):
        body = VALID_BODY.replace(
            "Adds a single Mint Glass startup screen.", "El startup cambia."
        )

        self.assertTrue(
            any("English" in error for error in validate_pr_body(body))
        )

    def test_rejects_an_empty_breaking_changes_section(self):
        body = VALID_BODY + "\n### Breaking changes (if any)\n"

        self.assertTrue(
            any("Breaking changes" in error for error in validate_pr_body(body))
        )


if __name__ == "__main__":
    unittest.main()
