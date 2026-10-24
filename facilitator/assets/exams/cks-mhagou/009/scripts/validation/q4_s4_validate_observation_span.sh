#!/bin/bash
# Item: the events cover at least 40 seconds of observation (a start-up margin is allowed) and were
# recorded after the exam started

source "$(dirname "$0")/../lib/nodes.sh"
source "$(dirname "$0")/../lib/csv-report.sh"
fetch_report "$NODE01" "${Q4_FILE:-/tmp/exam/mhagou-009-q4/report}" || exit 1
STARTED=$(ssh -o StrictHostKeyChecking=no "$NODE01" "cat /tmp/exam/mhagou-009-q4/.started" 2>/dev/null)

EPOCHS=$(echo "$REPORT" | while IFS=, read -r stamp _rest; do iso_epoch "$stamp"; done | sort -n)
FIRST=$(echo "$EPOCHS" | head -1); LAST=$(echo "$EPOCHS" | tail -1)
[ -n "$FIRST" ] || { echo "❌ The report has no valid timestamp"; exit 1; }

if [ -n "$STARTED" ]; then
  S=$(date -u -d "$STARTED" +%s)
  [ "$FIRST" -ge $((S - 5)) ] || { echo "❌ The report contains events from before the exam started"; exit 1; }
fi
SPAN=$((LAST - FIRST))
# Falco needs several seconds to start: a 40 second run yields about 30 seconds of events
[ "$SPAN" -ge 25 ] || { echo "❌ The events cover only $SPAN seconds: monitor for at least 40 seconds"; exit 1; }

echo "✅ The events cover $SPAN seconds"
exit 0
