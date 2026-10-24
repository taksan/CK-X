#!/bin/bash
# Item: the report contains the suspicious process (nc) with the uid it ran under (1000)

source "$(dirname "$0")/../lib/nodes.sh"
source "$(dirname "$0")/../lib/csv-report.sh"
fetch_report "$NODE01" "${Q4_FILE:-/tmp/exam/mhagou-009-q4/report}" || exit 1

CLEAN=$(echo "$REPORT" | awk -F, 'NF == 3 {gsub(/[][" ]/, "", $2); gsub(/[][" ]/, "", $3); print $2 "," $3}')
if ! echo "$CLEAN" | grep -qx '1000,nc'; then
  if echo "$CLEAN" | grep -q ',nc$'; then
    echo "❌ The process nc is in the report but not with the uid it really ran under (1000)"
  else
    echo "❌ The suspicious process of the container is not in the report"
  fi
  exit 1
fi

echo "✅ The report contains the suspicious process nc executed as uid 1000"
exit 0
