#!/usr/bin/env bash
# Validation script for migration tool outputs
# Usage: ./tests/validate_migration.sh reports/migration_report_YYYYMMDD_HHMMSS.csv

set -euo pipefail

if [[ $# -eq 0 ]]; then
  echo "Usage: $0 <csv_file>"
  echo "Example: $0 reports/migration_report_20250324_101530.csv"
  exit 1
fi

CSV_FILE="$1"

if [[ ! -f "$CSV_FILE" ]]; then
  echo "ERROR: CSV file not found: $CSV_FILE"
  exit 1
fi

echo "Validating: $CSV_FILE"
echo ""

# Count rows
TOTAL_ROWS=$(wc -l < "$CSV_FILE")
echo "✓ Total rows: $TOTAL_ROWS"

# Count by status
SUCCESS_COUNT=$(grep -c 'SUCCESS' "$CSV_FILE" || true)
fail_count=$(grep -c 'FAIL' "$CSV_FILE" || true)
FAIL_VALIDATION=$(grep -c 'FAIL_VALIDATION' "$CSV_FILE" || true)

echo "✓ Successful migrations: $SUCCESS_COUNT"
echo "✓ Failed migrations: $fail_count"
echo "✓ Validation failures: $FAIL_VALIDATION"

# Show failed repos
if [[ $fail_count -gt 0 ]]; then
  echo ""
  echo "⚠ Failed repositories:"
  grep 'FAIL' "$CSV_FILE" | cut -d',' -f4 | sort | uniq
fi

echo ""
echo "Validation complete."
