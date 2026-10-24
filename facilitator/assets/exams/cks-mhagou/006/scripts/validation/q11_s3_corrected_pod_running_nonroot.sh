#!/bin/bash
# Pod test-pod (the corrected one) is Running and Ready under the restricted policy, with a
# non-root user in every regular container

NS="pss-test"
[ "$(kubectl get namespace "$NS" -o jsonpath='{.metadata.labels.pod-security\.kubernetes\.io/enforce}' 2>/dev/null)" = "restricted" ] \
  || { echo "❌ The restricted policy is not enforced in $NS: the Pod must run without weakening it"; exit 1; }

J=$(kubectl get pod test-pod -n "$NS" -o json 2>/dev/null)
[ -n "$J" ] || { echo "❌ Pod 'test-pod' not found in namespace '$NS'"; exit 1; }
[ "$(echo "$J" | jq -r '[.status.conditions[]? | select(.type == "Ready")] | first | .status // "False"')" = "True" ] || { echo "❌ Pod 'test-pod' is not Running and Ready"; exit 1; }

for c in $(echo "$J" | jq -r '.spec.containers[].name'); do
  U=$(kubectl exec -n "$NS" test-pod -c "$c" -- id -u 2>/dev/null)
  { [ -n "$U" ] && [ "$U" != "0" ]; } || { echo "❌ Container $c runs as UID '${U:-unknown}' (root or unreadable): a non-root UID is required"; exit 1; }
done

echo "✅ Pod 'test-pod' is Running and Ready, accepted by the restricted policy, and runs as non-root"
exit 0
