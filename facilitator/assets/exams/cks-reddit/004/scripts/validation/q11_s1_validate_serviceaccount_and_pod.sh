#!/bin/bash
# Validate frontend-sa (no automount) and the Pod frontend running with it and without a token

NS="web-team"

[ -n "$(kubectl get sa frontend-sa -n "$NS" -o name 2>/dev/null)" ] || { echo "❌ ServiceAccount 'frontend-sa' not found in namespace '$NS'"; exit 1; }
[ "$(kubectl get sa frontend-sa -n "$NS" -o jsonpath='{.automountServiceAccountToken}')" = "false" ] || { echo "❌ frontend-sa must have automountServiceAccountToken: false"; exit 1; }

[ "$(kubectl get pod frontend -n "$NS" -o jsonpath='{.spec.serviceAccountName}' 2>/dev/null)" = "frontend-sa" ] || { echo "❌ Pod 'frontend' does not exist or does not use frontend-sa"; exit 1; }
[ "$(kubectl get pod frontend -n "$NS" -o jsonpath='{.status.phase}')" = "Running" ] || { echo "❌ Pod 'frontend' is not running"; exit 1; }

if kubectl exec -n "$NS" frontend -- test -e /var/run/secrets/kubernetes.io/serviceaccount/token 2>/dev/null; then
  echo "❌ The Pod still has an API token mounted"
  exit 1
fi

echo "✅ frontend-sa does not automount credentials and Pod 'frontend' uses it"
exit 0
