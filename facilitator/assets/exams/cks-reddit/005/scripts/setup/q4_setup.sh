#!/bin/bash

# Setup for CKS-005 Question 4: review of the Services exposed outside the cluster.
# Namespace exposed-lab is exclusive. portal must stay reachable from outside; reports (NodePort)
# and admin (LoadBalancer) must become ClusterIP; cache is already internal.

source "$(dirname "$0")/../lib/wait-cluster.sh"

NS="exposed-lab"
ensure_namespace "$NS"
kubectl delete svc portal reports admin cache -n "$NS" --ignore-not-found >/dev/null 2>&1
kubectl delete deployment apps -n "$NS" --ignore-not-found >/dev/null 2>&1

kubectl apply -f - >/dev/null <<EOF
apiVersion: apps/v1
kind: Deployment
metadata: {name: apps, namespace: ${NS}}
spec:
  replicas: 1
  selector: {matchLabels: {app: apps}}
  template:
    metadata: {labels: {app: apps}}
    spec:
      containers:
      - name: web
        image: nginx:1.27-alpine
---
apiVersion: v1
kind: Service
metadata: {name: portal, namespace: ${NS}, annotations: {exposure: "public"}}
spec:
  type: NodePort
  selector: {app: apps}
  ports: [{port: 80, targetPort: 80}]
---
apiVersion: v1
kind: Service
metadata: {name: reports, namespace: ${NS}, annotations: {exposure: "internal"}}
spec:
  type: NodePort
  selector: {app: apps}
  ports: [{port: 8080, targetPort: 80}]
---
apiVersion: v1
kind: Service
metadata: {name: admin, namespace: ${NS}, annotations: {exposure: "internal"}}
spec:
  type: LoadBalancer
  selector: {app: apps}
  ports: [{port: 9090, targetPort: 80}]
---
apiVersion: v1
kind: Service
metadata: {name: cache, namespace: ${NS}, annotations: {exposure: "internal"}}
spec:
  selector: {app: apps}
  ports: [{port: 6379, targetPort: 80}]
EOF

echo "Setup completed for CKS-005 Question 4 (namespace '$NS')"
exit 0
