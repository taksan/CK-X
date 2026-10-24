#!/bin/bash
# Validate by behaviour: PersistentVolumeClaim changes in the namespace frontend are logged at
# Request level (with the request body); PVC changes in another namespace are not logged; the
# kube-proxy watches of the base policy are still not logged

NODE="${Q8_NODE:-k8s-api-server}"

CMD=$(kubectl get pods -n kube-system -l component=kube-apiserver -o jsonpath='{.items[0].spec.containers[0].command}' 2>/dev/null)
LOG=$(echo "$CMD" | grep -o -- '--audit-log-path=[^",]*' | head -1 | cut -d= -f2)
if [ -z "$LOG" ] || ! echo "$CMD" | grep -q -- '--audit-policy-file='; then
  echo "❌ kube-apiserver has no audit policy / audit log path configured"
  exit 1
fi
STARTED=$(kubectl get pods -n kube-system -l component=kube-apiserver -o jsonpath='{.items[0].status.containerStatuses[0].state.running.startedAt}' 2>/dev/null)

ID="ckx$RANDOM$RANDOM"
T0=$(date -u +%Y-%m-%dT%H:%M:%S)
PVC="apiVersion: v1
kind: PersistentVolumeClaim
metadata: {name: $ID}
spec:
  accessModes: [ReadWriteOnce]
  resources: {requests: {storage: 1Mi}}"
echo "$PVC" | kubectl apply -n frontend --dry-run=server -f - >/dev/null 2>&1
echo "$PVC" | kubectl apply -n audit-other --dry-run=server -f - >/dev/null 2>&1

level_of() { # namespace
  ssh -o StrictHostKeyChecking=no "$NODE" "grep -a '$ID' '$LOG' | tail -n 40" 2>/dev/null \
    | jq -Rrn --arg t "$T0" --arg ns "$1" '[inputs | fromjson? | select(.requestReceivedTimestamp >= $t and .objectRef.resource == "persistentvolumeclaims" and .objectRef.namespace == $ns and .stage == "ResponseComplete")] | last | .level // "not logged"'
}

IN="not logged"
for i in $(seq 1 10); do IN=$(level_of frontend); [ "$IN" != "not logged" ] && break; sleep 2; done
OUT=$(level_of audit-other)

if [ "$IN" != "Request" ]; then
  echo "❌ PVC changes in 'frontend' are logged at level '$IN', expected Request (rules after the final catch-all 'level: None' are never reached)"
  exit 1
fi
if [ "$OUT" != "not logged" ]; then
  echo "❌ PVC changes in another namespace are logged too ($OUT): the rule must be limited to the namespace frontend"
  exit 1
fi

LEAK=$(ssh -o StrictHostKeyChecking=no "$NODE" "grep -a '\"username\":\"system:kube-proxy\"' '$LOG' | grep -a '\"verb\":\"watch\"' | grep -aE '\"resource\":\"(endpoints|services)\"' | tail -n 50" 2>/dev/null \
  | jq -Rrn --arg s "$STARTED" '[inputs | fromjson? | select(.requestReceivedTimestamp > $s)] | length')
if [ "${LEAK:-0}" != "0" ]; then
  echo "❌ The kube-proxy watches excluded by the base policy are logged again: extend the base policy, do not replace it"
  exit 1
fi

echo "✅ PVC changes in 'frontend' are logged at Request level, other namespaces are not, and the base exclusions still apply"
exit 0
