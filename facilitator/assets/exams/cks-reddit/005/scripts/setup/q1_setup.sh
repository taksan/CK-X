#!/bin/bash

# Setup for CKS-005 Question 1: harden a Deployment with its securityContext.
# Namespace sandbox is exclusive to this question. The image (nginx-unprivileged) can run as any
# user, with no capabilities and a read-only root filesystem as long as /tmp is writable.

source "$(dirname "$0")/../lib/wait-cluster.sh"

NS="sandbox"
ensure_namespace "$NS"

kubectl apply -f - >/dev/null <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: build-agent
  namespace: ${NS}
spec:
  replicas: 2
  selector:
    matchLabels:
      app: build-agent
  template:
    metadata:
      labels:
        app: build-agent
    spec:
      containers:
      - name: agent
        image: nginxinc/nginx-unprivileged:1.27-alpine
        ports:
        - containerPort: 8080
        securityContext:
          runAsUser: 0
          allowPrivilegeEscalation: true
EOF

echo "Setup completed for CKS-005 Question 1 (namespace '$NS')"
exit 0
