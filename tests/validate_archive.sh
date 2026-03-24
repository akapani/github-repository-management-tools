#!/usr/bin/env bash
# Validation script for archive tool outputs
# Usage: ./tests/validate_archive.sh reports/archive_report_YYYYMMDD_HHMMSS.csv

set -euo pipefail

if [[ $# -eq 0 ]]; then
  echo "Usage: $0 <csv_file>"
  echo "Example: $0 reports/archive_report_20250324_101530.csv"
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
FAIL_COUNT=$(grep -c 'FAIL' "$CSV_FILE" || true)

echo "✓ Successful operations: $SUCCESS_COUNT"
echo "✓ Failed operations: $FAIL_COUNT"

# Count executed vs skipped
EXECUTED=$(grep -c '"true"' "$CSV_FILE" || true)
SKIPPED=$((TOTAL_ROWS - EXECUTED - 1))  # -1 for header

echo "✓ Operations executed: $EXECUTED"
echo "✓ Operations skipped (already in desired state): $SKIPPED"

# Show failed repos
if [[ $FAIL_COUNT -gt 0 ]]; then
  echo ""
  echo "⚠ Failed repositories:"
  grep 'FAIL' "$CSV_FILE" | cut -d',' -f3,4 | sed 's/\",\"/\//' | sed 's/\"//g'
fi

echo ""
echo "Validation complete."
