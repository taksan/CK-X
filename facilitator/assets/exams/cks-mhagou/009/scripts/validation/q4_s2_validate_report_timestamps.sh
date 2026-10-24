#!/bin/bash
# Item: every timestamp of the report is valid

source "$(dirname "$0")/../lib/nodes.sh"
source "$(dirname "$0")/../lib/csv-report.sh"
fetch_report "$NODE01" "${Q4_FILE:-/tmp/exam/mhagou-009-q4/report}" || exit 1

BAD=0
while IFS=, read -r stamp _rest; do
  [ -n "$stamp" ] || continue
  [ -n "$(iso_epoch "$stamp")" ] || { echo "❌ Invalid timestamp: '$stamp'"; exit 1; }
done <<< "$REPORT"

echo "✅ All timestamps are valid"
exit 0
