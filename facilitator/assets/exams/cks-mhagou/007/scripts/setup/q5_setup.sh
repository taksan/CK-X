#!/bin/bash

# Setup for MHAGOU-007 Question 5: Ingress with TLS and an HTTP to HTTPS redirect (Traefik).
# Namespace rocket is exclusive: Deployment + Service rocket-server. The certificate and the key
# (CN/SAN rocket-server.local, generated on every start) are files for the candidate.

source "$(dirname "$0")/../lib/wait-cluster.sh"

NS="rocket"
DIR="/tmp/exam/mhagou-007-q5"
ensure_namespace "$NS"
kubectl delete ingress --all -n "$NS" >/dev/null 2>&1
kubectl delete middlewares.traefik.io --all -n "$NS" >/dev/null 2>&1 || true
kubectl delete secret secret-tls -n "$NS" --ignore-not-found >/dev/null 2>&1

mkdir -p "${DIR:?}"
rm -f "${DIR:?}"/*
openssl req -x509 -nodes -newkey rsa:2048 -days 30 -subj '/CN=rocket-server.local' \
  -addext 'subjectAltName=DNS:rocket-server.local' -keyout "$DIR/rocket.key" -out "$DIR/rocket.crt" >/dev/null 2>&1

kubectl apply -f - >/dev/null <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: rocket-server
  namespace: ${NS}
spec:
  replicas: 1
  selector:
    matchLabels:
      app: rocket-server
  template:
    metadata:
      labels:
        app: rocket-server
    spec:
      containers:
      - name: web
        image: nginx:1.27-alpine
        command: ["/bin/sh", "-c"]
        args:
        - "printf 'MHagou rocket-server\\\\n' > /usr/share/nginx/html/index.html; exec nginx -g 'daemon off;'"
        ports:
        - name: http
          containerPort: 80
        readinessProbe:
          httpGet: {path: /, port: http}
          initialDelaySeconds: 2
          periodSeconds: 2
---
apiVersion: v1
kind: Service
metadata:
  name: rocket-server
  namespace: ${NS}
spec:
  selector:
    app: rocket-server
  ports:
  - name: http
    port: 80
    targetPort: http
EOF

kubectl rollout status deploy/rocket-server -n "$NS" --timeout=180s >/dev/null || { echo "WARNING: rocket-server is not ready"; exit 1; }

source "$(dirname "$0")/../lib/ingress-address.sh"
add_ingress_host rocket-server.local   # the candidate can curl the host directly

echo "Setup completed for MHAGOU-007 Question 5 (namespace '$NS', certificate files in $DIR)"
exit 0
