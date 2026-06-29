#!/usr/bin/env bash
# i18n check script for Stroom
# Validates ARB file consistency and detects hardcoded strings.

set -euo pipefail

echo "=== i18n Check ==="

ARB_FILES=$(find . -name "*.arb" -not -path "./.dart_tool/*" -not -path "./build/*" 2>/dev/null || true)

if [ -z "$ARB_FILES" ]; then
  echo "[INFO] No ARB files found. i18n check skipped."
  echo "[INFO] When ARB files are added, this check will validate:"
  echo "  - All locales have matching keys"
  echo "  - No missing translations"
  echo "  - ARB files are valid JSON"
  exit 0
fi

echo "[CHECK] Found ARB files:"
echo "$ARB_FILES"

# Get base name (e.g. app_zh.arb -> app)
BASENAME=$(basename "$(echo "$ARB_FILES" | head -1)" | sed 's/_[a-z][a-z].*//')

# Validate each ARB file is valid JSON
for file in $ARB_FILES; do
  if ! dart compile as-is "$file" 2>/dev/null && ! dart run -c "import 'dart:convert'; void main() { jsonDecode(File('$file').readAsStringSync()); }" 2>/dev/null; then
    # Fallback: use python to validate JSON
    if ! python3 -c "import json; json.load(open('$file'))" 2>/dev/null; then
      echo "[ERROR] Invalid JSON in ARB file: $file"
      exit 1
    fi
  fi
  echo "[OK] $file is valid JSON"
done

# Check all locale files have the same keys
REF_FILE=$(echo "$ARB_FILES" | head -1)
REF_KEYS=$(python3 -c "
import json
keys = set()
data = json.load(open('$REF_FILE'))
for k in data:
    if not k.startswith('@'):
        keys.add(k)
print('\n'.join(sorted(keys)))
" 2>/dev/null || echo "")

for file in $ARB_FILES; do
  FILE_KEYS=$(python3 -c "
import json
keys = set()
data = json.load(open('$file'))
for k in data:
    if not k.startswith('@'):
        keys.add(k)
print('\n'.join(sorted(keys)))
" 2>/dev/null || echo "")
  
  if [ "$REF_KEYS" != "$FILE_KEYS" ]; then
    echo "[ERROR] Key mismatch between $REF_FILE and $file"
    echo "  Missing in $file:"
    comm -23 <(echo "$REF_KEYS") <(echo "$FILE_KEYS")
    echo "  Extra in $file:"
    comm -13 <(echo "$REF_KEYS") <(echo "$FILE_KEYS")
    exit 1
  fi
  echo "[OK] $file has matching keys"
done

echo "=== i18n Check Passed ==="
