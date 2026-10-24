#!/bin/bash
# Item (by behaviour): the file /var/run/secrets/kubernetes.io/serviceaccount/token inside the Pod is a
# token of vault-sa (credited only when it comes from an explicit projected volume of the Pod)

NS="vault-lab"
J=$(kubectl get pod immutable-pod -n "$NS" -o json 2>/dev/null)
[ -n "$J" ] || { echo "❌ Pod 'immutable-pod' not found in namespace '$NS'"; exit 1; }
echo "$J" | jq -e 'any(.spec.volumes[]?; (.name | startswith("kube-api-access-") | not) and any(.projected.sources[]?; has("serviceAccountToken")))' >/dev/null \
  || { echo "❌ The token does not come from a projected volume defined in the Pod (the automounted one does not count)"; exit 1; }

TOKEN=$(kubectl exec -n "$NS" immutable-pod -- cat /var/run/secrets/kubernetes.io/serviceaccount/token 2>/dev/null)
[ -n "$TOKEN" ] || { echo "❌ /var/run/secrets/kubernetes.io/serviceaccount/token cannot be read inside the Pod"; exit 1; }

SUB=$(echo "$TOKEN" | cut -d. -f2 | tr '_-' '/+' | awk '{ while (length($0) % 4) $0 = $0 "="; print }' | base64 -d 2>/dev/null | jq -r '.sub // empty' 2>/dev/null)
[ "$SUB" = "system:serviceaccount:$NS:vault-sa" ] || { echo "❌ The token belongs to '${SUB:-nobody}', expected system:serviceaccount:$NS:vault-sa"; exit 1; }

echo "✅ The token of the Pod is a token of vault-sa from a projected volume"
exit 0
