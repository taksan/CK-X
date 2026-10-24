#!/bin/bash

# Setup for MHagou-003 Question 10: ServiceAccount tokens through a projected volume.
# Namespace token-lab is exclusive. Only the ServiceAccount token-bot exists: the candidate creates
# the token Secret and the Pod.

source "$(dirname "$0")/../lib/wait-cluster.sh"

NS="token-lab"
ensure_namespace "$NS"
kubectl delete pod token-pod -n "$NS" --ignore-not-found --now >/dev/null 2>&1
kubectl delete secret --all -n "$NS" >/dev/null 2>&1 || true
kubectl delete serviceaccount token-bot -n "$NS" --ignore-not-found >/dev/null 2>&1
kubectl create serviceaccount token-bot -n "$NS" >/dev/null

echo "Setup completed for MHagou-003 Question 10 (namespace '$NS', ServiceAccount token-bot)"
exit 0
