#!/bin/bash
# Validate a populated service-account-token Secret references app-sa

NAMESPACE="${Q2_NAMESPACE:-legacy-tokens}"
SA_NAME="app-sa"

FOUND=$(kubectl get secret -n "$NAMESPACE" -o json 2>/dev/null | jq -r --arg sa "$SA_NAME" '
  .items[] | select(.type == "kubernetes.io/service-account-token")
  | select(.metadata.annotations["kubernetes.io/service-account.name"] == $sa)
  | select((.data.token // "") != "") | .metadata.name' | head -1)

if [ -z "$FOUND" ]; then
  echo "❌ No populated Secret of type kubernetes.io/service-account-token references ServiceAccount '$SA_NAME' in '$NAMESPACE'"
  exit 1
fi

echo "✅ Secret '$FOUND' is a service-account-token Secret for ServiceAccount '$SA_NAME'"
exit 0
