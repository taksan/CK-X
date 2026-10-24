#!/bin/bash
# Behaviour: a fresh read of /tmp/mem in the workload that keeps the file makes Falco raise a
# WARNING alert that mentions /tmp/mem (read from the journal of the Falco service on node01)

source "$(dirname "$0")/../lib/nodes.sh"

NS="mem-watch"
NODE="$NODE01"

for i in $(seq 1 6); do
  T0=$(date -u +"%Y-%m-%d %H:%M:%S")
  kubectl exec -n "$NS" deploy/compute-c -- cat /tmp/mem >/dev/null 2>&1
  sleep 6
  LINES=$(ssh -o StrictHostKeyChecking=no "$NODE" "journalctl -u falco-modern-bpf --since '$T0' --no-pager 2>/dev/null | grep -F '/tmp/mem'" 2>/dev/null)
  if echo "$LINES" | grep -q 'Warning'; then
    echo "✅ Falco raises a WARNING alert for the read of /tmp/mem"
    exit 0
  fi
  [ -n "$LINES" ] && { echo "❌ Falco reports the read of /tmp/mem but not with the priority WARNING (output: $(echo "$LINES" | head -1 | cut -c1-160))"; exit 1; }
done

echo "❌ Falco did not raise an alert for a read of /tmp/mem (is the rule loaded? was the service restarted after the change?)"
exit 1
