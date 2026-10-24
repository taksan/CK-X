#!/bin/bash
# Validate the Pod token-pod runs with the ServiceAccount token-bot, without the automatic token mount

NS="token-lab"
J=$(kubectl get pod token-pod -n "$NS" -o json 2>/dev/null)
[ -n "$J" ] || { echo "❌ Pod 'token-pod' not found in namespace '$NS'"; exit 1; }

[ "$(echo "$J" | jq -r '.spec.serviceAccountName')" = "token-bot" ] || { echo "❌ Pod 'token-pod' does not use the ServiceAccount token-bot"; exit 1; }
[ "$(echo "$J" | jq -r '.spec.automountServiceAccountToken')" = "false" ] || { echo "❌ Pod 'token-pod' does not set automountServiceAccountToken: false"; exit 1; }
[ "$(echo "$J" | jq -r '.status.phase')" = "Running" ] || { echo "❌ Pod 'token-pod' is not running"; exit 1; }

if kubectl exec -n "$NS" token-pod -- test -e /var/run/secrets/kubernetes.io/serviceaccount/token 2>/dev/null; then
  echo "❌ The default ServiceAccount token is still mounted at /var/run/secrets/kubernetes.io/serviceaccount"
  exit 1
fi

echo "✅ Pod token-pod uses token-bot without the automatic token mount"
exit 0
