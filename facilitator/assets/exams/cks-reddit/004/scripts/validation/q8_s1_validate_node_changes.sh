#!/bin/bash
# Validate by behaviour that node changes are logged at RequestResponse level

source "$(dirname "$0")/../lib/nodes.sh"

NODE="${Q8_NODE:-k8s-api-server}"

CMD=$(kubectl get pods -n kube-system -l component=kube-apiserver -o jsonpath='{.items[0].spec.containers[0].command}' 2>/dev/null)
LOG=$(echo "$CMD" | grep -o -- '--audit-log-path=[^",]*' | head -1 | cut -d= -f2)
if [ -z "$LOG" ] || ! echo "$CMD" | grep -q -- '--audit-policy-file='; then
  echo "❌ kube-apiserver has no audit policy / audit log path configured"
  exit 1
fi

ID="ckx$RANDOM$RANDOM"
T0=$(date -u +%Y-%m-%dT%H:%M:%S)
# a side-effect-free change of a node (server-side dry-run)
kubectl label node "$NODE02" "ckx-audit-probe=$ID" --overwrite --dry-run=server >/dev/null 2>&1

LEVEL="not logged"
for i in $(seq 1 10); do
  LEVEL=$(ssh -o StrictHostKeyChecking=no "$NODE" "grep -a 'ckx-audit-probe' '$LOG' | grep -a '$ID' | tail -n 20" 2>/dev/null \
    | jq -Rrn --arg t "$T0" '[inputs | fromjson? | select(.requestReceivedTimestamp >= $t and .objectRef.resource == "nodes")] | last | .level // "not logged"')
  [ "$LEVEL" != "not logged" ] && break
  sleep 2
done

if [ "$LEVEL" != "RequestResponse" ]; then
  echo "❌ Node changes are logged at level '$LEVEL', expected RequestResponse (rules after the final catch-all 'level: None' are never reached)"
  exit 1
fi

echo "✅ Node changes are logged at RequestResponse level"
exit 0
