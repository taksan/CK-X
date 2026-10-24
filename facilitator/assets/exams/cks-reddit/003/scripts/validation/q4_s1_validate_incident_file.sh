#!/bin/bash
# Validate the incident file on node02: lines "timestamp,user,process" for processes spawned
# in containers, including the one the workload spawns. Falco may add a prefix
# ("<time>: <priority> ") and extra fields after the triple: both are tolerated.

NODE="node02"
FILE="${Q4_FILE:-/tmp/exam/cks-003-q4/alerts/details}"

CONTENT=$(ssh -o StrictHostKeyChecking=no "$NODE" "cat '$FILE'" 2>/dev/null)
if [ -z "$CONTENT" ]; then
  echo "❌ The incident file '$FILE' does not exist on $NODE or is empty"
  exit 1
fi

# lines in the format timestamp,user,process; other lines (Falco may also print its default
# alerts into the same file) are ignored
RE='([0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9:.]+(Z|[+-][0-9]{2}:?[0-9]{2})?),([^,[:space:]]+),([^,[:space:]]+)'
GOOD=$(echo "$CONTENT" | grep -cE "$RE")
if [ "$GOOD" -lt 5 ]; then
  echo "❌ Only $GOOD lines are in the format timestamp,uid/username,processName (at least 5 events are expected)"
  exit 1
fi

TRIPLES=$(echo "$CONTENT" | grep -oE "$RE")

if ! echo "$TRIPLES" | awk -F, '{print $3}' | grep -qx 'whoami'; then
  echo "❌ The processes spawned by the Pod beacon (namespace runtime-watch) were not detected: the file must contain the events of every container of the node, whichever Falco rule reports them (check that your rule and your filters keep them)"
  exit 1
fi

echo "✅ $GOOD events in the format timestamp,uid/username,processName, including the process spawned by the Pod beacon"
exit 0
