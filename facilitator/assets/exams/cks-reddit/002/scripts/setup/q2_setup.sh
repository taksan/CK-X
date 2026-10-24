#!/bin/bash

# Setup for Question 2: ServiceAccount token and manual mount
#
# Namespace legacy-tokens (exclusive to this question) with a Pod that uses the
# namespace's default ServiceAccount and the automatically mounted token.

source "$(dirname "$0")/../lib/wait-cluster.sh"

NAMESPACE="legacy-tokens"

ensure_namespace "$NAMESPACE"

kubectl delete pod web -n "$NAMESPACE" --ignore-not-found --wait=false >/dev/null 2>&1 || true

kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: web
  namespace: ${NAMESPACE}
spec:
  containers:
  - name: nginx
    image: nginx
EOF

if [ $? -ne 0 ]; then
  echo "Failed to create the initial pod 'web' in namespace '$NAMESPACE'"
  exit 1
fi

echo "Setup completed for CKS-002 Question 2 (namespace '$NAMESPACE')"
exit 0
