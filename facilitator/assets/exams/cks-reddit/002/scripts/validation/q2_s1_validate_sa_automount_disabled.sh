#!/bin/bash
# Validate the new ServiceAccount app-sa exists in legacy-tokens with automounting disabled

NAMESPACE="${Q2_NAMESPACE:-legacy-tokens}"
SA_NAME="app-sa"

if ! kubectl get serviceaccount "$SA_NAME" -n "$NAMESPACE" >/dev/null 2>&1; then
  echo "❌ ServiceAccount '$SA_NAME' not found in namespace '$NAMESPACE'"
  exit 1
fi

AUTOMOUNT=$(kubectl get serviceaccount "$SA_NAME" -n "$NAMESPACE" -o jsonpath='{.automountServiceAccountToken}')
if [ "$AUTOMOUNT" != "false" ]; then
  echo "❌ ServiceAccount '$SA_NAME' does not have automountServiceAccountToken set to false"
  exit 1
fi

echo "✅ ServiceAccount '$SA_NAME' exists with automatic token mounting disabled"
exit 0
