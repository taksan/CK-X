#!/bin/bash
# Item: the observation lasted at least 20 seconds (Falco needs several seconds to start, so the events span
# about 10 seconds less than the run) and happened after the exam started

source "$(dirname "$0")/../lib/nodes.sh"
source "$(dirname "$0")/../lib/csv-report.sh"
fetch_report "$NODE02" "${Q7_FILE:-/tmp/exam/mhagou-009-q7/falco-incident.txt}" || exit 1
STARTED=$(ssh -o StrictHostKeyChecking=no "$NODE02" "cat /tmp/exam/mhagou-009-q7/.started" 2>/dev/null)

EPOCHS=$(echo "$REPORT" | while IFS=, read -r stamp _rest; do iso_epoch "$stamp"; done | sort -n)
FIRST=$(echo "$EPOCHS" | head -1); LAST=$(echo "$EPOCHS" | tail -1)
[ -n "$FIRST" ] || { echo "❌ The report has no valid timestamp"; exit 1; }
if [ -n "$STARTED" ]; then
  S=$(date -u -d "$STARTED" +%s)
  [ "$FIRST" -ge $((S - 5)) ] || { echo "❌ The report contains events from before the exam started"; exit 1; }
fi
SPAN=$((LAST - FIRST))
[ "$SPAN" -ge 9 ] || { echo "❌ The events cover only $SPAN seconds: keep Falco running for at least 20 seconds"; exit 1; }

echo "✅ The events cover $SPAN seconds"
exit 0
