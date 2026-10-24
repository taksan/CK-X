#!/bin/bash

# Setup for CKS-002 Question 12: RuntimeClass sandboxed (runsc) and server namespace

source "$(dirname "$0")/../lib/wait-cluster.sh"

set -euo pipefail

NAMESPACE="server"

# Ensure namespace exists
ensure_namespace "$NAMESPACE"

# Clean any previous RuntimeClass and workloads used in this question
kubectl delete runtimeclass sandboxed --ignore-not-found >/dev/null 2>&1 || true
kubectl delete deployment workload1 workload2 workload3 -n "$NAMESPACE" --ignore-not-found >/dev/null 2>&1 || true

# Seed three simple deployments in the server namespace without runtimeClassName
kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: workload1
  namespace: ${NAMESPACE}
spec:
  replicas: 1
  selector:
    matchLabels:
      app: workload1
  template:
    metadata:
      labels:
        app: workload1
    spec:
      containers:
      - name: app
        image: nginx
        ports:
        - containerPort: 80
EOF

kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: workload2
  namespace: ${NAMESPACE}
spec:
  replicas: 1
  selector:
    matchLabels:
      app: workload2
  template:
    metadata:
      labels:
        app: workload2
    spec:
      containers:
      - name: app
        image: busybox
        command: ["sh", "-c", "sleep 3600"]
EOF

kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: workload3
  namespace: ${NAMESPACE}
spec:
  replicas: 1
  selector:
    matchLabels:
      app: workload3
  template:
    metadata:
      labels:
        app: workload3
    spec:
      containers:
      - name: app
        image: busybox
        command: ["sh", "-c", "sleep 3600"]
EOF

echo "Setup completed for CKS-002 Question 12 (server namespace workloads seeded)"
exit 0
