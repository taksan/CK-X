#!/bin/bash

# Setup for MHAGOU-007 Question 1: a Service that is exposed outside the cluster.
# Namespace exposure-lab is exclusive. Deployment nginx + Service nginx-external (NodePort).

source "$(dirname "$0")/../lib/wait-cluster.sh"

NS="exposure-lab"
ensure_namespace "$NS"
kubectl delete service nginx-external -n "$NS" --ignore-not-found --wait=true >/dev/null 2>&1

kubectl apply -f - >/dev/null <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx
  namespace: ${NS}
spec:
  replicas: 1
  selector:
    matchLabels:
      app: nginx
  template:
    metadata:
      labels:
        app: nginx
    spec:
      containers:
      - name: nginx
        image: nginx:1.27-alpine
        ports:
        - containerPort: 80
        readinessProbe:
          httpGet: {path: /, port: 80}
          initialDelaySeconds: 2
          periodSeconds: 3
---
apiVersion: v1
kind: Service
metadata:
  name: nginx-external
  namespace: ${NS}
spec:
  type: NodePort
  selector:
    app: nginx
  ports:
  - port: 80
    targetPort: 80
EOF

kubectl rollout status deploy/nginx -n "$NS" --timeout=180s >/dev/null || { echo "WARNING: nginx is not ready"; exit 1; }

echo "Setup completed for MHAGOU-007 Question 1 (namespace '$NS')"
exit 0
