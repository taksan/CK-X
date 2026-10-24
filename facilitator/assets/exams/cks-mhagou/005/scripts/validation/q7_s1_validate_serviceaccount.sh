#!/bin/bash
# The ServiceAccount minimal-sa exists in service-account-caution and does not automount its token

NS="service-account-caution"
kubectl get serviceaccount minimal-sa -n "$NS" >/dev/null 2>&1 || { echo "❌ ServiceAccount 'minimal-sa' not found in namespace '$NS'"; exit 1; }
[ "$(kubectl get serviceaccount minimal-sa -n "$NS" -o jsonpath='{.automountServiceAccountToken}')" = "false" ] \
  || { echo "❌ minimal-sa does not disable token automounting (automountServiceAccountToken: false is missing on the ServiceAccount)"; exit 1; }

echo "✅ minimal-sa exists with automountServiceAccountToken: false"
exit 0
