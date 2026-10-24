#!/bin/bash
# Validate the events file on node01: lines of the rule "Invoice process" (timestamp,user,processName
# with an ISO 8601 timestamp) for the Pod invoice, recorded after the exam started, over >= 30 s
# of monitoring. Other lines (for example from the broad rule) are ignored.

source "$(dirname "$0")/../lib/nodes.sh"

DIR="${Q14_DIR:-/tmp/exam/cks-005-q14}"
FILE="$DIR/events"
EVENTS=$(ssh -o StrictHostKeyChecking=no node01 "cat '$FILE'" 2>/dev/null)
STARTED=$(ssh -o StrictHostKeyChecking=no node01 "cat '$DIR/.started'" 2>/dev/null)
[ -n "$(echo "$EVENTS" | tr -d '[:space:]')" ] || { echo "❌ $FILE does not exist on $NODE01 or is empty"; exit 1; }

RE='[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9:.]+(Z|[+-][0-9]{2}:?[0-9]{2}),[^,[:space:]]+,whoami$'
LINES=$(echo "$EVENTS" | grep -oE "$RE")
N=$(echo "$LINES" | grep -c .)
if [ "$N" -lt 5 ]; then
  echo "❌ Only $N lines in the format timestamp,user,processName for the process of the Pod invoice (30 seconds of monitoring give about 6 or more): were the events of invoice hidden by another rule?"
  exit 1
fi

EPOCHS=$(echo "$LINES" | cut -d, -f1 | while read -r t; do date -u -d "$t" +%s 2>/dev/null; done | sort -n)
FIRST=$(echo "$EPOCHS" | head -1)
LAST=$(echo "$EPOCHS" | tail -1)
if [ -n "$STARTED" ] && [ "$FIRST" -lt "$(date -u -d "$STARTED" +%s)" ]; then
  echo "❌ The file contains events recorded before the exam started"
  exit 1
fi
# Falco needs a few seconds to start and the Pod spawns a process every 4 s: a 30 s run covers ~21 s of events
if [ $((LAST - FIRST)) -lt 18 ]; then
  echo "❌ The events of invoice cover only $((LAST - FIRST)) seconds: monitor for at least 30 seconds"
  exit 1
fi

echo "✅ $N events of the Pod invoice covering $((LAST - FIRST)) seconds"
exit 0
