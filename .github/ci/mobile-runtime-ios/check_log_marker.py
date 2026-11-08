#!/usr/bin/env python3
"""Match simulator output markers as complete lines, ignoring ANSI styling."""

import re
import sys
from pathlib import Path

ANSI_CONTROL = re.compile(r"\x1b(?:\[[0-?]*[ -/]*[@-~]|\][^\x07]*(?:\x07|\x1b\\))")


def contains_marker(output: str, expected_markers: str) -> bool:
    output = ANSI_CONTROL.sub("", output)
    expected = set(expected_markers.splitlines())
    return any(
        line == marker or line.startswith(marker + " ")
        for line in output.splitlines()
        for marker in expected
    )


if __name__ == "__main__":
    log_path, expected_markers = sys.argv[1:]
    output = Path(log_path).read_text(encoding="utf-8", errors="replace")
    raise SystemExit(0 if contains_marker(output, expected_markers) else 1)
