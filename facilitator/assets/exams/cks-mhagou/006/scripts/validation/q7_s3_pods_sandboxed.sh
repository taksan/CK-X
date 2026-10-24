#!/bin/bash
# Behaviour: the running Pods of report-api are really sandboxed (the kernel log of the container is
# the one of gVisor)

NS="sandbox-lab"
PODS=$(kubectl get pods -n "$NS" -l app=report-api -o json 2>/dev/null | jq -r '.items[] | select(.metadata.deletionTimestamp == null and .status.phase == "Running" and .spec.runtimeClassName == "not-trusted") | .metadata.name')
[ -n "$PODS" ] || { echo "❌ No running Pod of 'report-api' uses the RuntimeClass not-trusted"; exit 1; }

for p in $PODS; do
  kubectl exec -n "$NS" "$p" -- dmesg 2>/dev/null | grep -qi 'gvisor' || { echo "❌ Pod $p does not run in a gVisor sandbox (dmesg does not show gVisor)"; exit 1; }
done

echo "✅ The Pods of 'report-api' run in a gVisor sandbox"
exit 0
