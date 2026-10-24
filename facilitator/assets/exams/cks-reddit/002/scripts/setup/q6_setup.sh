#!/bin/bash

# Setup for Question 6: Istio mTLS STRICT in payments namespace

source "$(dirname "$0")/../lib/wait-cluster.sh"

NAMESPACE="payments"

# Create namespace if it doesn't exist
ensure_namespace "$NAMESPACE"

# Explicitly disable injection initially so candidates must enable it
kubectl label namespace "$NAMESPACE" istio-injection=disabled --overwrite >/dev/null 2>&1 || true

# Create a couple of sample workloads without sidecars (injection disabled)

# payments-api deployment
kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: payments-api
  namespace: ${NAMESPACE}
spec:
  replicas: 2
  selector:
    matchLabels:
      app: payments-api
  template:
    metadata:
      labels:
        app: payments-api
    spec:
      containers:
      - name: payments-api
        image: nginx
        ports:
        - containerPort: 80
EOF

# payments-worker deployment
kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: payments-worker
  namespace: ${NAMESPACE}
spec:
  replicas: 1
  selector:
    matchLabels:
      app: payments-worker
  template:
    metadata:
      labels:
        app: payments-worker
    spec:
      containers:
      - name: payments-worker
        image: busybox
        command: ["sh", "-c", "sleep 3600"]
EOF

echo "Setup completed for CKS-002 Question 6 in namespace '$NAMESPACE'"
exit 0
