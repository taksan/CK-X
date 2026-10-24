#!/bin/bash

# Setup for CKS-003 Question 15: projected ServiceAccount token. Namespace projected-tokens
# is exclusive to this question; Pod token-demo uses the default ServiceAccount.

source "$(dirname "$0")/../lib/wait-cluster.sh"

NAMESPACE="projected-tokens"

ensure_namespace "$NAMESPACE"

kubectl delete pod token-demo -n "$NAMESPACE" --ignore-not-found --wait=false >/dev/null 2>&1
kubectl delete serviceaccount api-client -n "$NAMESPACE" --ignore-not-found >/dev/null 2>&1

kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: token-demo
  namespace: ${NAMESPACE}
spec:
  containers:
  - name: web
    image: nginx:1.27-alpine
EOF

echo "Setup completed for CKS-003 Question 15 (namespace '$NAMESPACE')"
exit 0
