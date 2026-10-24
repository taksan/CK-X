#!/bin/bash

# Setup for CKS-004 Question 2: a custom seccomp profile on node01 (the profile directory does
# not exist: the candidate creates it). Namespace secure-app is exclusive to this question.
# busybox is used on purpose: a profile that only allows four syscalls (as in the original
# exercise) cannot run an nginx container at all.

source "$(dirname "$0")/../lib/wait-cluster.sh"
source "$(dirname "$0")/../lib/nodes.sh"

NAMESPACE="secure-app"

ensure_namespace "$NAMESPACE"
ssh -o StrictHostKeyChecking=no node01 'rm -rf /var/lib/kubelet/seccomp'

kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: webapp
  namespace: ${NAMESPACE}
spec:
  replicas: 2
  selector:
    matchLabels:
      app: webapp
  template:
    metadata:
      labels:
        app: webapp
    spec:
      nodeSelector:
        kubernetes.io/hostname: $NODE01
      containers:
      - name: webapp
        image: busybox:1.36.1
        command: ["sh", "-c", "sleep 36000"]
EOF

echo "Setup completed for CKS-004 Question 2 (namespace '$NAMESPACE', Pods run on $NODE01)"
exit 0
