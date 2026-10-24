#!/bin/bash
# Validate the incident report on node01: lines "[timestamp],[uid],[processName]" for the processes
# spawned in the Pod tomcat, and only for it (not for the other Pod of the namespace)

NODE="node01"
FILE="${Q7_FILE:-/tmp/exam/cks-004-q7/report}"

CONTENT=$(ssh -o StrictHostKeyChecking=no "$NODE" "cat '$FILE'" 2>/dev/null)
if [ -z "$CONTENT" ]; then
  echo "❌ The report '$FILE' does not exist on $NODE or is empty"
  exit 1
fi

RE='\[[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9:.]+(Z|[+-][0-9]{2}:?[0-9]{2})?\],\[[^],[:space:]]+\],\[[^],[:space:]]+\]'
GOOD=$(echo "$CONTENT" | grep -cE "$RE")
if [ "$GOOD" -lt 5 ]; then
  echo "❌ Only $GOOD lines are in the format [timestamp],[uid],[processName] (at least 5 events are expected)"
  exit 1
fi

NAMES=$(echo "$CONTENT" | grep -oE "$RE" | sed -E 's/.*,\[([^]]*)\]$/\1/')

if ! echo "$NAMES" | grep -qx 'whoami'; then
  echo "❌ The processes spawned in the Pod tomcat were not detected: the report must contain every process that the Pod spawns during the monitoring"
  exit 1
fi

if echo "$NAMES" | grep -qx 'hostname'; then
  echo "❌ The report contains processes of the other Pod (batch): only the Pod tomcat had to be monitored"
  exit 1
fi

echo "✅ $GOOD events in the format [timestamp],[uid],[processName], only for the Pod tomcat"
exit 0
