#!/bin/bash
# Deployment report-api uses the RuntimeClass not-trusted and its rollout is complete

NS="sandbox-lab"
J=$(kubectl get deployment report-api -n "$NS" -o json 2>/dev/null)
[ -n "$J" ] || { echo "❌ Deployment 'report-api' not found in namespace '$NS' (it must be edited, not deleted)"; exit 1; }

[ "$(echo "$J" | jq -r '.spec.template.spec.runtimeClassName // ""')" = "not-trusted" ] \
  || { echo "❌ The Pod template of 'report-api' does not set runtimeClassName: not-trusted"; exit 1; }

WANT=$(echo "$J" | jq -r '.spec.replicas')
ST=$(echo "$J" | jq -r '"\(.status.updatedReplicas // 0)/\(.status.readyReplicas // 0)/\(.status.replicas // 0)"')
[ "$ST" = "$WANT/$WANT/$WANT" ] || { echo "❌ The rollout is not complete ($ST updated/ready/total, expected $WANT of each): does the RuntimeClass exist?"; exit 1; }

echo "✅ Deployment 'report-api' runs with the RuntimeClass not-trusted ($WANT ready replicas)"
exit 0
