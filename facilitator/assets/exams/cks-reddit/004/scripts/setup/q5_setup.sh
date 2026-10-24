#!/bin/bash

# Setup for CKS-004 Question 5: default-deny egress. Namespace egress-lab is exclusive to this
# question, with a client Pod and a server Pod.

source "$(dirname "$0")/../lib/wait-cluster.sh"

NAMESPACE="egress-lab"

ensure_namespace "$NAMESPACE"
kubectl delete networkpolicy default-deny -n "$NAMESPACE" --ignore-not-found >/dev/null 2>&1

kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: client
  namespace: ${NAMESPACE}
  labels:
    app: client
spec:
  containers:
  - name: client
    image: busybox:1.36.1
    command: ["sh", "-c", "sleep 36000"]
---
apiVersion: v1
kind: Pod
metadata:
  name: server
  namespace: ${NAMESPACE}
  labels:
    app: server
spec:
  containers:
  - name: web
    image: nginx:1.27-alpine
EOF

echo "Setup completed for CKS-004 Question 5 (namespace '$NAMESPACE')"
exit 0
