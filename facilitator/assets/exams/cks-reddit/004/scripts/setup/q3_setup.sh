#!/bin/bash

# Setup for CKS-004 Question 3: workloads that share the node (host namespaces, host paths).
# Namespace ci-cd is exclusive to this question. builder shares hostPID, hostIPC, hostNetwork
# and mounts /etc of the node; reporter and cache are fine and must stay as they are.

source "$(dirname "$0")/../lib/wait-cluster.sh"

NAMESPACE="ci-cd"

ensure_namespace "$NAMESPACE"

kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: builder
  namespace: ${NAMESPACE}
spec:
  replicas: 1
  selector:
    matchLabels:
      app: builder
  template:
    metadata:
      labels:
        app: builder
    spec:
      hostPID: true
      hostIPC: true
      hostNetwork: true
      containers:
      - name: builder
        image: busybox:1.36.1
        command: ["sh", "-c", "sleep 36000"]
        volumeMounts:
        - name: node-etc
          mountPath: /host-etc
          readOnly: true
      volumes:
      - name: node-etc
        hostPath:
          path: /etc
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: reporter
  namespace: ${NAMESPACE}
spec:
  replicas: 1
  selector:
    matchLabels:
      app: reporter
  template:
    metadata:
      labels:
        app: reporter
    spec:
      containers:
      - name: reporter
        image: busybox:1.36.1
        command: ["sh", "-c", "sleep 36000"]
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: cache
  namespace: ${NAMESPACE}
spec:
  replicas: 1
  selector:
    matchLabels:
      app: cache
  template:
    metadata:
      labels:
        app: cache
    spec:
      containers:
      - name: cache
        image: busybox:1.36.1
        command: ["sh", "-c", "sleep 36000"]
EOF

echo "Setup completed for CKS-004 Question 3 (namespace '$NAMESPACE')"
exit 0
