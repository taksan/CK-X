#!/bin/bash
# Item: the report on the first worker node is CSV with exactly timestamp,uid,processName per line, no header

source "$(dirname "$0")/../lib/nodes.sh"
source "$(dirname "$0")/../lib/csv-report.sh"
fetch_report "$NODE01" "${Q4_FILE:-/tmp/exam/mhagou-009-q4/report}" || exit 1

BAD=$(echo "$REPORT" | awk -F, 'NF == 0 {next} NF != 3 || $2 !~ /^[0-9]+$/ || $1 !~ /^[^[:space:]]+$/ || $3 !~ /^[^[:space:]]+$/ {print NR ": " $0}' | head -3)
if [ -n "$BAD" ]; then
  echo "❌ Lines that are not 'timestamp,uid,processName' (numeric uid, three fields, no header): $(echo "$BAD" | head -1 | cut -c1-120)"
  exit 1
fi
N=$(echo "$REPORT" | grep -c .)
[ "$N" -ge 5 ] || { echo "❌ Only $N events in the report: at least 5 are expected after 40 seconds"; exit 1; }

echo "✅ $N events in the format timestamp,uid,processName"
exit 0
