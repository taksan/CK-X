#!/bin/bash
# The Deployment secure-app has 2 ready replicas, uses nginx and runs with the ServiceAccount minimal-sa

NS="service-account-caution"
J=$(kubectl get deployment secure-app -n "$NS" -o json 2>/dev/null)
[ -n "$J" ] || { echo "❌ Deployment 'secure-app' not found in namespace '$NS'"; exit 1; }

[ "$(echo "$J" | jq -r '.spec.replicas')" = "2" ] || { echo "❌ The Deployment must have 2 replicas (found $(echo "$J" | jq -r '.spec.replicas'))"; exit 1; }
[ "$(echo "$J" | jq -r '.spec.template.spec.serviceAccountName // "default"')" = "minimal-sa" ] \
  || { echo "❌ The Deployment does not use the ServiceAccount minimal-sa (it uses $(echo "$J" | jq -r '.spec.template.spec.serviceAccountName // "default"'))"; exit 1; }
echo "$J" | jq -e '[.spec.template.spec.containers[].image] | any(startswith("nginx"))' >/dev/null || { echo "❌ The Deployment does not use the nginx image"; exit 1; }

READY=$(echo "$J" | jq -r '.status.readyReplicas // 0'); UPD=$(echo "$J" | jq -r '.status.updatedReplicas // 0'); TOT=$(echo "$J" | jq -r '.status.replicas // 0')
[ "$READY" = "2" ] && [ "$UPD" = "2" ] && [ "$TOT" = "2" ] || { echo "❌ The rollout is not complete: updated/ready/total = $UPD/$READY/$TOT, expected 2/2/2"; exit 1; }

echo "✅ Deployment secure-app runs 2 ready replicas with the ServiceAccount minimal-sa"
exit 0
