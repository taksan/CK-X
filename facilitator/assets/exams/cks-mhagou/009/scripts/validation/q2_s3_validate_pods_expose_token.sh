#!/bin/bash
# Item: the rolled-out Pods really expose a readable token from a projected volume (its name and readOnly are judged by item 2)

source "$(dirname "$0")/../lib/projected-token.sh"
NS="monitoring"

J=$(kubectl get deployment stats-monitor -n "$NS" -o json 2>/dev/null)
[ -n "$J" ] || { echo "❌ Deployment stats-monitor not found"; exit 1; }
token_projected_ok "$J" '.spec.template.spec' || { echo "❌ The Deployment does not project the token yet"; exit 1; }

WANT=$(echo "$J" | jq -r '.spec.replicas')
ST=$(echo "$J" | jq -r '"\(.status.updatedReplicas // 0)/\(.status.readyReplicas // 0)/\(.status.replicas // 0)"')
[ "$ST" = "$WANT/$WANT/$WANT" ] || { echo "❌ The rollout is not complete ($ST updated/ready/total, expected $WANT of each)"; exit 1; }

PODS=$(kubectl get pods -n "$NS" -o json | jq -r '.items[] | select(.metadata.deletionTimestamp == null and .status.phase == "Running") | .metadata.name')
[ -n "$PODS" ] || { echo "❌ No running Pod"; exit 1; }

for pod in $PODS; do
  PJ=$(kubectl get pod "$pod" -n "$NS" -o json)
  token_projected_ok "$PJ" '.spec' || { echo "❌ Pod $pod does not have a projected serviceAccountToken volume mounted at the token path (old Pod of a previous revision?)"; exit 1; }
  TOKEN=$(kubectl exec -n "$NS" "$pod" -- cat /var/run/secrets/kubernetes.io/serviceaccount/token 2>/dev/null)
  [ -n "$TOKEN" ] || { echo "❌ Pod $pod: /var/run/secrets/kubernetes.io/serviceaccount/token is missing or empty"; exit 1; }
  SUB=$(echo "$TOKEN" | cut -d. -f2 | tr '_-' '/+' | awk '{ l = length($0) % 4; if (l == 2) print $0 "=="; else if (l == 3) print $0 "="; else print $0 }' | base64 -d 2>/dev/null | jq -r '.sub // empty' 2>/dev/null)
  [ "$SUB" = "system:serviceaccount:$NS:stats-monitor-sa" ] || { echo "❌ The token of Pod $pod belongs to '${SUB:-<unreadable>}', expected stats-monitor-sa"; exit 1; }
done

echo "✅ The Pods expose a valid token of stats-monitor-sa at the required path from the projected volume"
exit 0
