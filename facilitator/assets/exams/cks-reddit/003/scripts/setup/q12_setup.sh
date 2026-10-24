#!/bin/bash

# Setup for CKS-003 Question 12: Secrets. Namespace safe is exclusive to this question.
# The secret "admin" gets random values on every run, so they cannot be memorised.

source "$(dirname "$0")/../lib/wait-cluster.sh"

NAMESPACE="safe"
WORKDIR="/tmp/exam/cks-003-q12"

ensure_namespace "$NAMESPACE"

kubectl delete secret admin newsecret -n "$NAMESPACE" --ignore-not-found >/dev/null 2>&1
kubectl delete pods --all -n "$NAMESPACE" --wait=false >/dev/null 2>&1

kubectl create secret generic admin -n "$NAMESPACE" \
  --from-literal=username="admin-$(openssl rand -hex 3)" \
  --from-literal=password="$(openssl rand -hex 8)" >/dev/null

mkdir -p "$WORKDIR"
rm -f "${WORKDIR:?}"/*

echo "Setup completed for CKS-003 Question 12 (namespace '$NAMESPACE', output directory $WORKDIR)"
exit 0
