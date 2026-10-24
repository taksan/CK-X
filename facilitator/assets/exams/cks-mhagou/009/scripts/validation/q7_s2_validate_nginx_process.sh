#!/bin/bash
# Item: the processes executed in the nginx container (ls, as uid 0) are in the report

source "$(dirname "$0")/../lib/nodes.sh"
source "$(dirname "$0")/../lib/csv-report.sh"
fetch_report "$NODE02" "${Q7_FILE:-/tmp/exam/mhagou-009-q7/falco-incident.txt}" || exit 1

if ! echo "$REPORT" | grep -qx '\[[^][,]*\],\[0\],\[ls\]'; then
  echo "❌ The process executed in the nginx container (ls, uid 0) is not in the report"
  exit 1
fi

echo "✅ The report contains the processes of the nginx container"
exit 0
