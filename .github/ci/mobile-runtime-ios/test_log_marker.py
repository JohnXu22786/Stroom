import unittest

from check_log_marker import contains_marker


class MarkerMatchingTests(unittest.TestCase):
    def test_marker_echoed_in_source_or_stack_does_not_count(self):
        marker = "IOS_RAW_UTF8_ROUNDTRIP:5374726f6f6d20e5ada6e4b9a020f09f9982"
        echoed = f"throw new Error('{marker}')\n    at eval ({marker})\n"

        self.assertFalse(contains_marker(echoed, marker))

    def test_complete_marker_line_matches_with_terminal_styling(self):
        marker = "IOS_RAW_UTF8_ROUNDTRIP:5374726f6f6d20e5ada6e4b9a020f09f9982"

        self.assertTrue(contains_marker(f"\x1b[32m{marker}\x1b[0m\n", marker))

    def test_only_one_of_the_explicit_raw_utf8_outcomes_matches(self):
        markers = (
            "IOS_RAW_UTF8_ROUNDTRIP:5374726f6f6d20e5ada6e4b9a020f09f9982\n"
            "IOS_RAW_UTF8_RANGEERROR:RangeError:Index out of range"
        )

        self.assertTrue(contains_marker("IOS_RAW_UTF8_RANGEERROR:RangeError:Index out of range\n", markers))
        self.assertFalse(contains_marker("IOS_RAW_UTF8_RANGEERROR:RangeError:other\n", markers))


if __name__ == "__main__":
    unittest.main()
