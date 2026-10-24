#!/bin/bash
# Item: the other container of the Pod (log-agent: hostname) is not in the report (credited when the
# nginx events are there)

source "$(dirname "$0")/../lib/nodes.sh"
source "$(dirname "$0")/../lib/csv-report.sh"
fetch_report "$NODE02" "${Q7_FILE:-/tmp/exam/mhagou-009-q7/falco-incident.txt}" || exit 1

echo "$REPORT" | grep -qx '\[[^][,]*\],\[0\],\[ls\]' || { echo "❌ The nginx container events are not in the report yet: nothing to credit"; exit 1; }

if echo "$REPORT" | grep -q ',\[hostname\]$'; then
  echo "❌ The report contains processes of the other container of the Pod (hostname of log-agent): only the nginx container had to be monitored"
  exit 1
fi

echo "✅ Only the nginx container was monitored"
exit 0
