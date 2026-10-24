#!/bin/bash

# Setup for MHagou-005 Question 2: TLS Ingress. Namespace secure-ingress is exclusive.
# The backend (Deployment web, Service web-service:80) and a valid TLS Secret secure-app-tls
# (certificate for secure-app.example.com, one year) exist; there is no Ingress.

source "$(dirname "$0")/../lib/wait-cluster.sh"

NS="secure-ingress"
ensure_namespace "$NS"
kubectl delete ingress --all -n "$NS" >/dev/null 2>&1

kubectl apply -f - >/dev/null <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web
  namespace: ${NS}
spec:
  replicas: 1
  selector:
    matchLabels:
      app: tls-web
  template:
    metadata:
      labels:
        app: tls-web
    spec:
      containers:
      - name: web
        image: nginx:1.27-alpine
        ports:
        - containerPort: 80
        readinessProbe:
          httpGet: {path: /, port: 80}
          initialDelaySeconds: 2
          periodSeconds: 2
---
apiVersion: v1
kind: Service
metadata:
  name: web-service
  namespace: ${NS}
spec:
  selector:
    app: tls-web
  ports:
  - port: 80
    targetPort: 80
EOF

KEYS=$(mktemp -d)
openssl req -x509 -newkey rsa:2048 -nodes -days 365 -subj '/CN=secure-app.example.com' \
  -addext 'subjectAltName=DNS:secure-app.example.com' \
  -keyout "$KEYS/tls.key" -out "$KEYS/tls.crt" >/dev/null 2>&1 || { echo "WARNING: unable to create the certificate"; rm -rf "$KEYS"; exit 1; }
kubectl create secret tls secure-app-tls -n "$NS" --cert="$KEYS/tls.crt" --key="$KEYS/tls.key" --dry-run=client -o yaml | kubectl apply -f - >/dev/null
rm -rf "$KEYS"

kubectl rollout status deployment/web -n "$NS" --timeout=180s >/dev/null 2>&1 || { echo "WARNING: the backend is not ready"; exit 1; }

source "$(dirname "$0")/../lib/ingress-address.sh"
add_ingress_host secure-app.example.com   # the candidate can curl the host directly

echo "Setup completed for MHagou-005 Question 2 (namespace '$NS')"
exit 0
