#!/bin/bash

# Setup for CKS-004 Question 16: Pod Security Admission. Namespace team-blue is exclusive.
# Deployment privileged-runner runs a privileged container (busybox).

source "$(dirname "$0")/../lib/wait-cluster.sh"

NS="team-blue"
DIR="/tmp/exam/cks-004-q16"

ensure_namespace "$NS"
kubectl label ns "$NS" pod-security.kubernetes.io/enforce- >/dev/null 2>&1 || true
kubectl delete deployment privileged-runner -n "$NS" --ignore-not-found >/dev/null 2>&1

mkdir -p "${DIR:?}"
rm -f "${DIR:?}"/*

kubectl apply -f - >/dev/null <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: privileged-runner
  namespace: ${NS}
spec:
  replicas: 1
  selector:
    matchLabels: {app: privileged-runner}
  template:
    metadata:
      labels: {app: privileged-runner}
    spec:
      containers:
      - name: runner
        image: busybox:1.36.1
        command: ["sleep", "86400"]
        securityContext:
          privileged: true
EOF

echo "Setup completed for CKS-004 Question 16 (namespace '$NS', output directory $DIR)"
exit 0
