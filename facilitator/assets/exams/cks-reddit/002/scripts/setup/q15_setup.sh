#!/bin/bash

# Setup for CKS-002 Question 15: Scan images with Trivy and remove vulnerable Pods

source "$(dirname "$0")/../lib/wait-cluster.sh"

NAMESPACE="supply-chain"
WORKDIR="/tmp/exam/cks-002-q15"

mkdir -p "$WORKDIR"
rm -f "$WORKDIR"/* 2>/dev/null || true

ensure_namespace "$NAMESPACE"
kubectl delete pod legacy-web old-httpd tools -n "$NAMESPACE" --ignore-not-found >/dev/null 2>&1 || true

# Two Pods running very old images with CRITICAL vulnerabilities
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: legacy-web
  namespace: ${NAMESPACE}
spec:
  containers:
  - name: legacy-web
    image: nginx:1.14.2
---
apiVersion: v1
kind: Pod
metadata:
  name: old-httpd
  namespace: ${NAMESPACE}
spec:
  containers:
  - name: old-httpd
    image: httpd:2.4.39
---
apiVersion: v1
kind: Pod
metadata:
  name: tools
  namespace: ${NAMESPACE}
spec:
  containers:
  - name: tools
    image: busybox:1.36.1
    command: ["sh", "-c", "sleep 3600"]
EOF

# Warm up the Trivy vulnerability database so the first scan is fast (best effort)
if command -v trivy >/dev/null 2>&1; then
  trivy image --download-db-only --quiet >/dev/null 2>&1 || true
fi

echo "Setup completed for CKS-002 Question 15 (Pods created in '$NAMESPACE')"
exit 0
