#!/bin/bash
# Validate Pod web uses ServiceAccount app-sa and that the file
# /var/run/secrets/kubernetes.io/serviceaccount/token it sees is the token of the
# service-account-token Secret of app-sa (whatever way the Secret is mounted).

NAMESPACE="${Q2_NAMESPACE:-legacy-tokens}"
POD_NAME="${Q2_POD:-web}"
SA_NAME="app-sa"
TOKEN_PATH="/var/run/secrets/kubernetes.io/serviceaccount/token"

if ! kubectl get pod "$POD_NAME" -n "$NAMESPACE" >/dev/null 2>&1; then
  echo "❌ Pod '$POD_NAME' not found in namespace '$NAMESPACE'"
  exit 1
fi

USED_SA=$(kubectl get pod "$POD_NAME" -n "$NAMESPACE" -o jsonpath='{.spec.serviceAccountName}')
if [ "$USED_SA" != "$SA_NAME" ]; then
  echo "❌ Pod '$POD_NAME' does not use ServiceAccount '$SA_NAME' (current: '$USED_SA')"
  exit 1
fi

SECRETS=$(kubectl get secret -n "$NAMESPACE" -o json 2>/dev/null | jq -r --arg sa "$SA_NAME" '
  .items[] | select(.type == "kubernetes.io/service-account-token")
  | select(.metadata.annotations["kubernetes.io/service-account.name"] == $sa) | .metadata.name')
if [ -z "$SECRETS" ]; then
  echo "❌ No service-account-token Secret found that references ServiceAccount '$SA_NAME'"
  exit 1
fi

MOUNTED=""
for name in $SECRETS; do
  if kubectl get pod "$POD_NAME" -n "$NAMESPACE" -o json | jq -e --arg s "$name" '[.spec.volumes[]? | select(.secret.secretName == $s)] | length > 0' >/dev/null; then
    MOUNTED="$name"
    break
  fi
done
if [ -z "$MOUNTED" ]; then
  echo "❌ Pod '$POD_NAME' does not mount the token Secret of '$SA_NAME'"
  exit 1
fi

PHASE=$(kubectl get pod "$POD_NAME" -n "$NAMESPACE" -o jsonpath='{.status.phase}')
if [ "$PHASE" != "Running" ]; then
  echo "❌ Pod '$POD_NAME' is not running (phase: $PHASE)"
  exit 1
fi

# what the container sees at the token path must be the Secret's token
EXPECTED=$(kubectl get secret "$MOUNTED" -n "$NAMESPACE" -o jsonpath='{.data.token}' | base64 -d)
ACTUAL=$(kubectl exec "$POD_NAME" -n "$NAMESPACE" -- cat "$TOKEN_PATH" 2>/dev/null)
if [ -z "$EXPECTED" ] || [ "$ACTUAL" != "$EXPECTED" ]; then
  echo "❌ The file $TOKEN_PATH in '$POD_NAME' is not the token of Secret '$MOUNTED'"
  exit 1
fi

echo "✅ Pod '$POD_NAME' uses '$SA_NAME' and $TOKEN_PATH holds the token of Secret '$MOUNTED'"
exit 0
