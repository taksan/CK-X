#!/bin/bash

# Setup for MHagou-003 Question 2: Cilium mutual authentication.
# Namespace cilium-lab is exclusive. nginx (Service nginx:80) is the server; curlpod and other are
# clients. No CiliumNetworkPolicy exists: the candidate writes it.

source "$(dirname "$0")/../lib/wait-cluster.sh"

NS="cilium-lab"
ensure_namespace "$NS"
kubectl delete ciliumnetworkpolicy --all -n "$NS" >/dev/null 2>&1 || true

kubectl apply -f - >/dev/null <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx
  namespace: ${NS}
  labels: {app: nginx}
spec:
  replicas: 1
  selector:
    matchLabels: {app: nginx}
  template:
    metadata:
      labels: {app: nginx}
    spec:
      containers:
      - name: nginx
        image: nginx:1.27-alpine
        ports: [{containerPort: 80}]
---
apiVersion: v1
kind: Service
metadata:
  name: nginx
  namespace: ${NS}
spec:
  selector: {app: nginx}
  ports: [{port: 80, targetPort: 80}]
---
apiVersion: v1
kind: Pod
metadata:
  name: curlpod
  namespace: ${NS}
  labels: {app: curlpod}
spec:
  containers:
  - name: curl
    image: busybox:1.36.1
    command: ["sleep", "3600"]
---
apiVersion: v1
kind: Pod
metadata:
  name: other
  namespace: ${NS}
  labels: {app: other}
spec:
  containers:
  - name: curl
    image: busybox:1.36.1
    command: ["sleep", "3600"]
EOF

echo "Setup completed for MHagou-003 Question 2 (namespace '$NS')"
exit 0
