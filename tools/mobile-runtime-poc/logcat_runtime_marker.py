#!/usr/bin/env python3
"""Match a marker emitted by the Android sample's Node runtime logger."""

import re
import sys

THREADTIME_INFO_LINE = re.compile(
    r"^\S+\s+\S+\s+\d+\s+\d+\s+I\s+TestNode:\s?(.*)$"
)


def contains_runtime_marker(log: str, marker: str) -> bool:
    """Return whether a TestNode info-priority message contains marker."""
    return any(
        match and marker in match.group(1)
        for line in log.splitlines()
        for match in [THREADTIME_INFO_LINE.match(line)]
    )


if __name__ == "__main__":
    marker = sys.argv[1]
    raise SystemExit(0 if contains_runtime_marker(sys.stdin.read(), marker) else 1)
