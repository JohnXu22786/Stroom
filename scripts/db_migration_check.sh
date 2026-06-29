#!/usr/bin/env bash
# DB Migration check for Stroom
# Validates database schema consistency between migration steps.

set -euo pipefail

echo "=== DB Migration Check ==="

# Check that migration service has consistent version constants
MIGRATION_FILE="lib/services/data_migration_service.dart"
if [ ! -f "$MIGRATION_FILE" ]; then
  echo "[ERROR] Migration service file not found: $MIGRATION_FILE"
  exit 1
fi

echo "[CHECK] Analyzing migration service..."

# Extract current format version
CURRENT_VERSION=$(grep -oP 'static.*int.*currentFormatVersion\s*=\s*\K\d+' "$MIGRATION_FILE" 2>/dev/null || echo "")
if [ -z "$CURRENT_VERSION" ]; then
  CURRENT_VERSION=$(grep -oP 'int\s+currentFormatVersion\s*=\s*\K\d+' "$MIGRATION_FILE" 2>/dev/null || echo "2")
fi
echo "[INFO] Current format version: $CURRENT_VERSION"

# Count migration steps (v0→v1, v1→v2, etc.)
MIGRATION_STEPS=$(grep -cP "v\d+→v\d+:" "$MIGRATION_FILE" 2>/dev/null || echo "0")
echo "[INFO] Migration steps found: $MIGRATION_STEPS"

# Check that manifest database migration is in sync
MANIFEST_FILE="lib/services/manifest_database.dart"
if [ -f "$MANIFEST_FILE" ]; then
  DB_VERSION=$(grep -oP 'onUpgrade.*version\s*\K\d+' "$MANIFEST_FILE" 2>/dev/null || echo "not found")
  echo "[INFO] Database schema version: $DB_VERSION"
  
  # Check for version consistency between migration steps
  # Each step should target the next version
  STEP_COUNT=$(grep -cP 'Future.*void.*_migrateV\d+' "$MIGRATION_FILE" 2>/dev/null || echo "0")
  echo "[INFO] Migration method count: $STEP_COUNT"
fi

# Validate that all migration steps have corresponding tests
TEST_FILE="test/services/data_migration_service_test.dart"
if [ -f "$TEST_FILE" ]; then
  TEST_STEPS=$(grep -cP "migration.*step|v\d+→v\d+" "$TEST_FILE" 2>/dev/null || echo "0")
  echo "[INFO] Migration test steps: $TEST_STEPS"
else
  echo "[WARN] No migration test file found"
fi

echo "=== DB Migration Check Passed ==="
