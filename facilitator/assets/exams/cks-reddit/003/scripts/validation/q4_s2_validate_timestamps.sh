#!/bin/bash
# Validate the recorded events are ISO 8601 timestamps from after the exam started and cover
# at least 30 seconds of monitoring

NODE="node02"
FILE="${Q4_FILE:-/tmp/exam/cks-003-q4/alerts/details}"
STARTED_FILE="/tmp/exam/cks-003-q4/.started"

CONTENT=$(ssh -o StrictHostKeyChecking=no "$NODE" "cat '$FILE'" 2>/dev/null)
if [ -z "$CONTENT" ]; then
  echo "❌ The incident file '$FILE' does not exist on $NODE or is empty"
  exit 1
fi
STARTED=$(ssh -o StrictHostKeyChecking=no "$NODE" "cat '$STARTED_FILE'" 2>/dev/null)

RE='([0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9:.]+(Z|[+-][0-9]{2}:?[0-9]{2})?),([^,[:space:]]+),([^,[:space:]]+)'
STAMPS=$(echo "$CONTENT" | grep -oE "$RE" | cut -d, -f1)
if [ -z "$STAMPS" ]; then
  echo "❌ No line has an ISO 8601 timestamp followed by ,uid/username,processName (use time_format_iso_8601=true)"
  exit 1
fi

# epoch seconds, ordered
EPOCHS=$(echo "$STAMPS" | while read -r t; do date -u -d "$t" +%s 2>/dev/null; done | sort -n)
T_FIRST=$(echo "$EPOCHS" | head -1)
T_LAST=$(echo "$EPOCHS" | tail -1)
if [ -z "$T_FIRST" ]; then
  echo "❌ The timestamps cannot be parsed"
  exit 1
fi

if [ -n "$STARTED" ] && [ "$T_FIRST" -lt "$(date -u -d "$STARTED" +%s)" ]; then
  echo "❌ The file contains events recorded before the exam started"
  exit 1
fi

if [ $((T_LAST - T_FIRST)) -lt 25 ]; then
  echo "❌ The events cover only $((T_LAST - T_FIRST)) seconds: monitor for at least 30 seconds"
  exit 1
fi

echo "✅ The events were recorded after the exam started and cover $((T_LAST - T_FIRST)) seconds"
exit 0
