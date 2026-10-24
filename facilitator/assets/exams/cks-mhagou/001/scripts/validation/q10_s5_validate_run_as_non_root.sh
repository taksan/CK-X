#!/bin/bash
# Item (by behaviour): immutable-pod enforces runAsNonRoot and its process really runs with a non-zero UID

NS="vault-lab"
J=$(kubectl get pod immutable-pod -n "$NS" -o json 2>/dev/null)
[ -n "$J" ] || { echo "❌ Pod 'immutable-pod' not found in namespace '$NS'"; exit 1; }

# runAsNonRoot at Pod level or on every container
if ! echo "$J" | jq -e '.spec.securityContext.runAsNonRoot == true or all(.spec.containers[]; .securityContext.runAsNonRoot == true)' >/dev/null; then
  echo "❌ runAsNonRoot is not true (Pod securityContext or every container)"
  exit 1
fi

[ "$(echo "$J" | jq -r '.status.phase')" = "Running" ] || { echo "❌ immutable-pod is not running (runAsNonRoot needs a non-root runAsUser for this image)"; exit 1; }
UID_=$(kubectl exec -n "$NS" immutable-pod -- id -u 2>/dev/null)
if [ -z "$UID_" ] || [ "$UID_" = "0" ]; then
  echo "❌ The container process runs with UID '${UID_:-unknown}', expected a non-root UID"
  exit 1
fi

echo "✅ immutable-pod runs as UID $UID_ with runAsNonRoot"
exit 0
