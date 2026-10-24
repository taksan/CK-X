#!/bin/bash
# Validate the report covers at least 40 seconds and was recorded after the exam started

NODE="node01"
FILE="${Q7_FILE:-/tmp/exam/cks-004-q7/report}"
STARTED_FILE="/tmp/exam/cks-004-q7/.started"

CONTENT=$(ssh -o StrictHostKeyChecking=no "$NODE" "cat '$FILE'" 2>/dev/null)
[ -n "$CONTENT" ] || { echo "❌ The report '$FILE' does not exist on $NODE or is empty"; exit 1; }
STARTED=$(ssh -o StrictHostKeyChecking=no "$NODE" "cat '$STARTED_FILE'" 2>/dev/null)

RE='\[[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9:.]+(Z|[+-][0-9]{2}:?[0-9]{2})?\]'
EPOCHS=$(echo "$CONTENT" | grep -oE "$RE,\[" | grep -oE '[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9:.]+(Z|[+-][0-9]{2}:?[0-9]{2})?' | while read -r t; do date -u -d "$t" +%s 2>/dev/null; done | sort -n)
T_FIRST=$(echo "$EPOCHS" | head -1)
T_LAST=$(echo "$EPOCHS" | tail -1)
[ -n "$T_FIRST" ] || { echo "❌ No line has an ISO 8601 timestamp in brackets"; exit 1; }

if [ -n "$STARTED" ] && [ "$T_FIRST" -lt "$(date -u -d "$STARTED" +%s)" ]; then
  echo "❌ The report contains events recorded before the exam started"
  exit 1
fi

if [ $((T_LAST - T_FIRST)) -lt 36 ]; then
  echo "❌ The events cover only $((T_LAST - T_FIRST)) seconds: monitor for at least 40 seconds"
  exit 1
fi

echo "✅ The events cover $((T_LAST - T_FIRST)) seconds and were recorded after the exam started"
exit 0
