import unittest

from logcat_runtime_marker import contains_runtime_marker


class RuntimeMarkerTests(unittest.TestCase):
    def test_args_echo_cannot_fake_marker_but_runtime_output_matches(self):
        marker = "SHIM_BOOTSTRAP_EVAL_DONE"
        args_echo = (
            "11-08 10:22:33.123  1234  1234 V TestNode: Args: node -p "
            f"console.log('{marker}')"
        )
        runtime_output = f"11-08 10:22:34.123  1234  1234 I TestNode: {marker}"

        self.assertFalse(contains_runtime_marker(args_echo, marker))
        self.assertTrue(contains_runtime_marker(runtime_output, marker))

    def test_stack_source_does_not_match(self):
        marker = "RESULT:PASS"
        stack_source = f"11-08 10:22:33.123  1234  1234 E TestNode: at eval ({marker})"

        self.assertFalse(contains_runtime_marker(stack_source, marker))


if __name__ == "__main__":
    unittest.main()
