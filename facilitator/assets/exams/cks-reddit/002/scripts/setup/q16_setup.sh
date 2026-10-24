#!/bin/bash

# Setup for CKS-002 Question 16: Falco detection of /dev/mem access
#
# Three Deployments with neutral names in the batch-ops namespace. Only
# telemetry-agent reads /dev/mem (it runs privileged so that the device exists
# and the open() succeeds, which is what Falco detects). The other two are
# harmless and must keep running.

source "$(dirname "$0")/../lib/wait-cluster.sh"

set -euo pipefail

NAMESPACE="batch-ops"

ensure_namespace "$NAMESPACE"

# Workloads of previous versions of this question
kubectl delete deployment mem-hacker telemetry-agent image-resizer email-sender -n "$NAMESPACE" --ignore-not-found >/dev/null 2>&1 || true

kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: telemetry-agent
  namespace: ${NAMESPACE}
spec:
  replicas: 1
  selector:
    matchLabels:
      app: telemetry-agent
  template:
    metadata:
      labels:
        app: telemetry-agent
    spec:
      containers:
      - name: agent
        image: busybox
        securityContext:
          privileged: true
        command: ["sh", "-c", "while true; do sleep 5; dd if=/dev/mem of=/dev/null bs=1 count=1 2>/dev/null || true; done"]
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: image-resizer
  namespace: ${NAMESPACE}
spec:
  replicas: 1
  selector:
    matchLabels:
      app: image-resizer
  template:
    metadata:
      labels:
        app: image-resizer
    spec:
      containers:
      - name: worker
        image: busybox
        command: ["sh", "-c", "while true; do sleep 5; cat /etc/hostname >/dev/null; done"]
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: email-sender
  namespace: ${NAMESPACE}
spec:
  replicas: 1
  selector:
    matchLabels:
      app: email-sender
  template:
    metadata:
      labels:
        app: email-sender
    spec:
      containers:
      - name: worker
        image: busybox
        command: ["sh", "-c", "while true; do sleep 5; ls /tmp >/dev/null; done"]
EOF

# Remove any Falco rule file in a conventional candidate location
rm -f /home/candidate/rule.yaml 2>/dev/null || true

echo "Setup completed for CKS-002 Question 16 (workloads seeded in '$NAMESPACE')"
exit 0
