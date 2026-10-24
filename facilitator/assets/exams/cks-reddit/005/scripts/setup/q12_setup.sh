#!/bin/bash

# Setup for CKS-005 Question 12: Istio AuthorizationPolicy. Namespace mesh-lab is exclusive and
# has sidecar injection enabled. orders (Service orders:80) is called by two clients that use
# different ServiceAccounts: frontend (allowed) and scratch (must be denied).

source "$(dirname "$0")/../lib/wait-cluster.sh"

NS="mesh-lab"
ensure_namespace "$NS"
kubectl label namespace "$NS" istio-injection=enabled --overwrite >/dev/null 2>&1
kubectl delete authorizationpolicy --all -n "$NS" >/dev/null 2>&1 || true

kubectl apply -f - >/dev/null <<EOF
apiVersion: v1
kind: ServiceAccount
metadata: {name: orders, namespace: ${NS}}
---
apiVersion: v1
kind: ServiceAccount
metadata: {name: frontend, namespace: ${NS}}
---
apiVersion: v1
kind: ServiceAccount
metadata: {name: scratch, namespace: ${NS}}
---
apiVersion: apps/v1
kind: Deployment
metadata: {name: orders, namespace: ${NS}}
spec:
  replicas: 1
  selector: {matchLabels: {app: orders}}
  template:
    metadata: {labels: {app: orders}}
    spec:
      serviceAccountName: orders
      containers:
      - name: web
        image: nginx:1.27-alpine
        ports: [{containerPort: 80}]
---
apiVersion: v1
kind: Service
metadata: {name: orders, namespace: ${NS}}
spec:
  selector: {app: orders}
  ports: [{port: 80, targetPort: 80}]
---
apiVersion: v1
kind: Pod
metadata: {name: web-client, namespace: ${NS}, labels: {app: web-client}}
spec:
  serviceAccountName: frontend
  containers:
  - {name: curl, image: "curlimages/curl:8.10.1", command: ["sleep", "86400"]}
---
apiVersion: v1
kind: Pod
metadata: {name: batch-client, namespace: ${NS}, labels: {app: batch-client}}
spec:
  serviceAccountName: scratch
  containers:
  - {name: curl, image: "curlimages/curl:8.10.1", command: ["sleep", "86400"]}
EOF

echo "Setup completed for CKS-005 Question 12 (namespace '$NS' with sidecar injection)"
exit 0
