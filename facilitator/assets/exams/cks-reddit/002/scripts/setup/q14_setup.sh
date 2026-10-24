#!/bin/bash

# Setup for CKS-002 Question 14: Pod Security Admission restricted in secure-team

source "$(dirname "$0")/../lib/wait-cluster.sh"

set -euo pipefail

NAMESPACE="secure-team"

# Ensure namespace exists and is labeled to enforce restricted profile
ensure_namespace "$NAMESPACE"
kubectl label namespace "$NAMESPACE" \
  pod-security.kubernetes.io/enforce=restricted \
  pod-security.kubernetes.io/enforce-version=latest \
  --overwrite >/dev/null 2>&1 || true

# Remove any existing Deployment created by previous attempts
kubectl delete deployment webapp -n "$NAMESPACE" --ignore-not-found >/dev/null 2>&1 || true

# The insecure manifest the candidate has to fix, on the jumphost like the other
# provided files. nginx-unprivileged is used so that the fixed Deployment can
# really run under the restricted profile (the stock nginx image cannot).
WORKDIR="/tmp/exam/cks-002-q14"
mkdir -p "$WORKDIR"
cat > "$WORKDIR/insecure-deployment.yaml" <<'MANIFEST'
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: webapp
  namespace: secure-team
spec:
  replicas: 1
  selector:
    matchLabels:
      app: webapp
  template:
    metadata:
      labels:
        app: webapp
    spec:
      containers:
      - name: webapp
        image: nginxinc/nginx-unprivileged:1.27-alpine
        ports:
        - containerPort: 8080
        securityContext:
          privileged: true
          runAsUser: 0
          capabilities:
            add: ["NET_ADMIN"]
        volumeMounts:
        - mountPath: /data
          name: host-data
      volumes:
      - name: host-data
        hostPath:
          path: /tmp
MANIFEST

echo "Setup completed for CKS-002 Question 14 (manifest written to $WORKDIR)"
exit 0
