#!/bin/bash

# Setup for MHAGOU-002 Question 4: a Secret mounted read-only in a Pod. The namespace secret-lab
# is exclusive to this question; nothing is created, the candidate builds the Secret and the Pod.

source "$(dirname "$0")/../lib/wait-cluster.sh"

NS="secret-lab"
ensure_namespace "$NS"
kubectl delete pod secretpod -n "$NS" --ignore-not-found --now >/dev/null 2>&1
kubectl delete secret secret1 -n "$NS" --ignore-not-found >/dev/null 2>&1

echo "Setup completed for MHAGOU-002 Question 4 (namespace '$NS')"
exit 0
