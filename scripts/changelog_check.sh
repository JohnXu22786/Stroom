#!/usr/bin/env bash
# Version and changelog check for Stroom
# Validates version bump consistency and changelog updates.

set -euo pipefail

echo "=== Version / Changelog Check ==="

PUBSPEC="pubspec.yaml"
CHANGELOG="CHANGELOG.md"

# Check pubspec exists
if [ ! -f "$PUBSPEC" ]; then
  echo "[ERROR] pubspec.yaml not found"
  exit 1
fi

# Extract current version
CURRENT_VERSION=$(grep -oP '^version:\s*\K\S+' "$PUBSPEC" 2>/dev/null || echo "unknown")
echo "[INFO] Current version: $CURRENT_VERSION"

# Check changelog exists
if [ ! -f "$CHANGELOG" ]; then
  echo "[WARN] CHANGELOG.md not found — create one at the project root."
  echo "  A CHANGELOG helps track releases and breaking changes."
else
  echo "[OK] CHANGELOG.md exists"
  
  # Check if latest version is in changelog
  if grep -q "$CURRENT_VERSION" "$CHANGELOG" 2>/dev/null; then
    echo "[OK] Current version $CURRENT_VERSION found in CHANGELOG.md"
  else
    echo "[WARN] Current version $CURRENT_VERSION not found in CHANGELOG.md"
    echo "  If this is a new release, add an entry to CHANGELOG.md."
  fi
fi

# Check for semantic version format
if echo "$CURRENT_VERSION" | grep -qP '^\d+\.\d+\.\d+'; then
  echo "[OK] Version format is valid semver"
else
  echo "[WARN] Version format may not follow semver: $CURRENT_VERSION"
fi

echo "=== Version / Changelog Check Passed ==="
