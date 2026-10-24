#!/bin/bash

# Setup for MHagou-004 Question 1: a ServiceAccount that does not mount its token.
# Namespace secret-room is exclusive to this question; it starts without the ServiceAccount.

source "$(dirname "$0")/../lib/wait-cluster.sh"

NS="secret-room"
ensure_namespace "$NS"

kubectl delete pod --all -n "$NS" --ignore-not-found --now >/dev/null 2>&1
kubectl delete serviceaccount hidden-user -n "$NS" --ignore-not-found >/dev/null 2>&1

echo "Setup completed for MHagou-004 Question 1 (namespace '$NS')"
exit 0
