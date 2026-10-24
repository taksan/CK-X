#!/bin/bash
# Pod gvisor-pod (sandbox-test): nginx image and the RuntimeClass runsc-class

NS="sandbox-test"
J=$(kubectl get pod gvisor-pod -n "$NS" -o json 2>/dev/null)
[ -n "$J" ] || { echo "❌ Pod 'gvisor-pod' not found in namespace '$NS'"; exit 1; }
echo "$J" | jq -e '[.spec.containers[].image] | any(startswith("nginx") or test("/nginx(:|$)"))' >/dev/null || { echo "❌ The Pod does not use the nginx image"; exit 1; }
RC=$(echo "$J" | jq -r '.spec.runtimeClassName // ""')
[ "$RC" = "runsc-class" ] || { echo "❌ The Pod uses the runtimeClassName '${RC:-<none>}', expected runsc-class"; exit 1; }
echo "✅ gvisor-pod (nginx) uses the RuntimeClass runsc-class"
exit 0
