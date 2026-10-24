#!/bin/bash
# Item: the ServiceAccount vault-sa does not automount its API token

NS="vault-lab"
kubectl get serviceaccount vault-sa -n "$NS" >/dev/null 2>&1 || { echo "❌ ServiceAccount 'vault-sa' not found in namespace '$NS'"; exit 1; }
V=$(kubectl get serviceaccount vault-sa -n "$NS" -o jsonpath='{.automountServiceAccountToken}' 2>/dev/null)
[ "$V" = "false" ] || { echo "❌ vault-sa automountServiceAccountToken is '${V:-unset (true)}', expected false"; exit 1; }

echo "✅ vault-sa does not automount its token"
exit 0
