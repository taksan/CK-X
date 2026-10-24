#!/bin/bash
# Item: one [timestamp],[uid],[processName] record per line, nothing else

source "$(dirname "$0")/../lib/nodes.sh"
source "$(dirname "$0")/../lib/csv-report.sh"
fetch_report "$NODE02" "${Q7_FILE:-/tmp/exam/mhagou-009-q7/falco-incident.txt}" || exit 1

BAD=$(echo "$REPORT" | grep -vE '^\[[^][,]+\],\[[0-9]+\],\[[^][,]+\]$' | head -1)
if [ -n "$BAD" ]; then
  echo "❌ A line is not in the format [timestamp],[uid],[processName]: '$(echo "$BAD" | cut -c1-100)'"
  exit 1
fi
N=$(echo "$REPORT" | grep -c .)
[ "$N" -ge 5 ] || { echo "❌ Only $N events in the report"; exit 1; }

echo "✅ $N records in the format [timestamp],[uid],[processName]"
exit 0
