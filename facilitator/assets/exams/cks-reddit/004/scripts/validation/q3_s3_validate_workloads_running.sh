#!/bin/bash
# Validate builder was fixed and still runs, and that reporter and cache were left alone

NS="ci-cd"

# builder: fixed (no host namespaces, no host paths) and running
JSON=$(kubectl get deployment builder -n "$NS" -o json 2>/dev/null)
[ -n "$JSON" ] || { echo "❌ Deployment 'builder' was deleted; it had to be fixed"; exit 1; }
if echo "$JSON" | jq -e '.spec.template.spec | (.hostPID == true or .hostIPC == true or .hostNetwork == true or ([.volumes[]? | select(.hostPath != null)] | length > 0))' >/dev/null; then
  echo "❌ builder still shares the node (host namespaces or host paths)"
  exit 1
fi

for d in builder reporter cache; do
  READY=$(kubectl get deployment "$d" -n "$NS" -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
  WANT=$(kubectl get deployment "$d" -n "$NS" -o jsonpath='{.spec.replicas}' 2>/dev/null)
  if [ -z "$WANT" ] || [ "${READY:-0}" != "$WANT" ]; then
    echo "❌ Deployment '$d' is missing or not ready (${READY:-0}/${WANT:-?})"
    exit 1
  fi
done

# reporter and cache were not touched: no new generation
for d in reporter cache; do
  if [ "$(kubectl get deployment "$d" -n "$NS" -o jsonpath='{.metadata.generation}')" != "1" ]; then
    echo "❌ Deployment '$d' was modified: only the Deployment that shares the node had to be changed"
    exit 1
  fi
done

echo "✅ builder is fixed and running; reporter and cache were left alone"
exit 0
