#!/bin/bash

# Setup for CKS-005 Question 15: Traefik middlewares (strip a path prefix, redirect a legacy path).
# Namespace traefik-lab is exclusive. The Pod reports (nginx) only serves "/" and "/health.txt",
# behind the Service reports. No Ingress and no Middleware exist: the candidate creates them.

source "$(dirname "$0")/../lib/wait-cluster.sh"

NS="traefik-lab"
ensure_namespace "$NS"
kubectl delete ingress --all -n "$NS" >/dev/null 2>&1
kubectl delete middlewares.traefik.io --all -n "$NS" >/dev/null 2>&1 || true

kubectl apply -f - >/dev/null <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: reports
  namespace: ${NS}
  labels: {app: reports}
spec:
  containers:
  - name: web
    image: nginx:1.27-alpine
    command:
    - sh
    - -c
    - |
      echo ok > /usr/share/nginx/html/health.txt
      echo reports-home > /usr/share/nginx/html/index.html
      exec nginx -g 'daemon off;'
---
apiVersion: v1
kind: Service
metadata:
  name: reports
  namespace: ${NS}
spec:
  selector: {app: reports}
  ports: [{port: 80, targetPort: 80}]
EOF

source "$(dirname "$0")/../lib/ingress-address.sh"
add_ingress_host lab.example.com   # the candidate can curl the host directly

echo "Setup completed for CKS-005 Question 15 (namespace '$NS')"
exit 0
