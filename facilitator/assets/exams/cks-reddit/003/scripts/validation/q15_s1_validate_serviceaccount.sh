#!/bin/bash
# Validate the new ServiceAccount api-client exists with automatic token mounting disabled

NS="${Q15_NAMESPACE:-projected-tokens}"

if ! kubectl get serviceaccount api-client -n "$NS" >/dev/null 2>&1; then
  echo "❌ ServiceAccount 'api-client' not found in namespace '$NS'"
  exit 1
fi

if [ "$(kubectl get serviceaccount api-client -n "$NS" -o jsonpath='{.automountServiceAccountToken}')" != "false" ]; then
  echo "❌ ServiceAccount 'api-client' does not have automountServiceAccountToken set to false"
  exit 1
fi

echo "✅ ServiceAccount 'api-client' exists with automatic token mounting disabled"
exit 0
