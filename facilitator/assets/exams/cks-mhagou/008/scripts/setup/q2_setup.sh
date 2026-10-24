#!/bin/bash

# Setup for MHAGOU-008 Question 2: Ingress with TLS and an HTTP to HTTPS redirect (Traefik).
# Namespace secure-web is exclusive. Deployment + Service secure-app and the TLS Secret web-tls
# (CN/SAN secure-app.company.com, generated on every start) exist; the Ingress does not.

source "$(dirname "$0")/../lib/wait-cluster.sh"

NS="secure-web"
WORK=$(mktemp -d)

ensure_namespace "$NS"
kubectl delete ingress --all -n "$NS" >/dev/null 2>&1
kubectl delete middlewares.traefik.io --all -n "$NS" >/dev/null 2>&1 || true

openssl req -x509 -nodes -newkey rsa:2048 -days 30 -subj '/CN=secure-app.company.com' \
  -addext 'subjectAltName=DNS:secure-app.company.com' -keyout "$WORK/tls.key" -out "$WORK/tls.crt" >/dev/null 2>&1
kubectl create secret tls web-tls -n "$NS" --cert="$WORK/tls.crt" --key="$WORK/tls.key" --dry-run=client -o yaml | kubectl apply -f - >/dev/null
rm -rf "${WORK:?}"

kubectl apply -f - >/dev/null <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: secure-app
  namespace: ${NS}
spec:
  replicas: 1
  selector:
    matchLabels:
      app: secure-app
  template:
    metadata:
      labels:
        app: secure-app
    spec:
      containers:
      - name: web
        image: nginx:1.27-alpine
        command: ["/bin/sh", "-c"]
        args:
        - "printf 'MHagou secure-app\\\\n' > /usr/share/nginx/html/index.html; exec nginx -g 'daemon off;'"
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
  name: secure-app
  namespace: ${NS}
spec:
  selector:
    app: secure-app
  ports:
  - name: http
    port: 80
    targetPort: http
EOF

kubectl rollout status deploy/secure-app -n "$NS" --timeout=180s >/dev/null || { echo "WARNING: secure-app is not ready"; exit 1; }

source "$(dirname "$0")/../lib/ingress-address.sh"
add_ingress_host secure-app.company.com   # the candidate can curl the host directly

echo "Setup completed for MHAGOU-008 Question 2 (namespace '$NS')"
exit 0
