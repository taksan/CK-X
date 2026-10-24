#!/bin/bash
# Validate the namespace enforces restricted and no privileged Pod runs anymore

NS="team-blue"
L=$(kubectl get ns "$NS" -o jsonpath='{.metadata.labels.pod-security\.kubernetes\.io/enforce}' 2>/dev/null)
[ "$L" = "restricted" ] || { echo "❌ Namespace '$NS' does not enforce the restricted profile (enforce='$L')"; exit 1; }

PRIV=$(kubectl get pods -n "$NS" -o json | jq '[.items[] | select(.metadata.deletionTimestamp == null) | select(any(.spec.containers[]; .securityContext.privileged == true))] | length')
[ "$PRIV" = "0" ] || { echo "❌ A privileged Pod is still running in '$NS' (delete it so that the Deployment tries to recreate it)"; exit 1; }

echo "✅ '$NS' enforces restricted and no privileged Pod runs"
exit 0
