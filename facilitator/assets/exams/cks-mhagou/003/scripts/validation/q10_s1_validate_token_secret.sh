#!/bin/bash
# Validate a ServiceAccount token Secret of token-bot exists in token-lab and its token is populated

NS="token-lab"
J=$(kubectl get secrets -n "$NS" -o json 2>/dev/null)
N=$(echo "$J" | jq '[.items[] | select(.type == "kubernetes.io/service-account-token") | select(.metadata.annotations["kubernetes.io/service-account.name"] == "token-bot")] | length')
[ "${N:-0}" -ge 1 ] || { echo "❌ No Secret of type kubernetes.io/service-account-token with the annotation kubernetes.io/service-account.name: token-bot in namespace '$NS'"; exit 1; }

for i in $(seq 1 10); do
  OK=$(kubectl get secrets -n "$NS" -o json | jq '[.items[] | select(.type == "kubernetes.io/service-account-token") | select(.metadata.annotations["kubernetes.io/service-account.name"] == "token-bot") | select((.data.token // "") != "")] | length')
  [ "${OK:-0}" -ge 1 ] && break
  sleep 2
done
[ "${OK:-0}" -ge 1 ] || { echo "❌ The token Secret has no token (the controller fills it in a few seconds: is the ServiceAccount name in the annotation right?)"; exit 1; }

echo "✅ A ServiceAccount token Secret of token-bot exists and holds a token"
exit 0
