#!/bin/bash
# Validate the Pod frontend uses backend-qa and runs

NS="qa"

JSON=$(kubectl get pod frontend -n "$NS" -o json 2>/dev/null)
[ -n "$JSON" ] || { echo "❌ Pod 'frontend' not found in namespace '$NS'"; exit 1; }

[ "$(echo "$JSON" | jq -r '.spec.serviceAccountName')" = "backend-qa" ] || { echo "❌ Pod 'frontend' does not use the ServiceAccount 'backend-qa'"; exit 1; }
[ "$(echo "$JSON" | jq -r '.status.phase')" = "Running" ] || { echo "❌ Pod 'frontend' is not running"; exit 1; }

echo "✅ Pod 'frontend' runs with the ServiceAccount 'backend-qa'"
exit 0
