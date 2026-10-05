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
        self.assertTrue(any("[type]" in error for error in errors))

    def test_rejects_non_latin_description_text(self):
        errors = validate_pr_body(VALID_BODY + "\n中文说明")

        self.assertTrue(any("English" in error for error in errors))

    def test_rejects_an_empty_breaking_changes_section(self):
        body = VALID_BODY + "\n### Breaking changes (if any)\n"

        self.assertTrue(
            any("Breaking changes" in error for error in validate_pr_body(body))
        )


if __name__ == "__main__":
    unittest.main()
