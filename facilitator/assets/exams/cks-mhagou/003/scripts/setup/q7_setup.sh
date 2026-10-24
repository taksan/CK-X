#!/bin/bash

# Setup for MHagou-003 Question 7: automatic sidecar injection and namespace-wide STRICT mTLS.
# Namespaces (exclusive): restricted-zone (the payment service httpbin, NOT injected) and legacy-zone
# (a plain client Pod without a sidecar). No PeerAuthentication and no injection label exist.

source "$(dirname "$0")/../lib/wait-cluster.sh"

ensure_namespace restricted-zone
ensure_namespace legacy-zone
kubectl label namespace restricted-zone istio-injection- istio.io/rev- >/dev/null 2>&1 || true
kubectl label namespace legacy-zone istio-injection=disabled --overwrite >/dev/null
kubectl delete peerauthentication --all -n restricted-zone --ignore-not-found >/dev/null 2>&1 || true
kubectl delete pod legacy -n legacy-zone --ignore-not-found --now >/dev/null 2>&1
kubectl delete deployment payment-service -n restricted-zone --ignore-not-found >/dev/null 2>&1

kubectl apply -f - >/dev/null <<EOF
apiVersion: v1
kind: ServiceAccount
metadata:
  name: payment
  namespace: restricted-zone
---
apiVersion: v1
kind: Service
metadata:
  name: payment-service
  namespace: restricted-zone
  labels: {app: payment-service}
spec:
  selector: {app: payment-service}
  ports:
  - name: http
    port: 8000
    targetPort: 80
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: payment-service
  namespace: restricted-zone
spec:
  replicas: 1
  selector:
    matchLabels: {app: payment-service}
  template:
    metadata:
      labels: {app: payment-service}
    spec:
      serviceAccountName: payment
      containers:
      - name: httpbin
        image: docker.io/kennethreitz/httpbin
        ports: [{containerPort: 80}]
---
apiVersion: v1
kind: Pod
metadata:
  name: legacy
  namespace: legacy-zone
spec:
  containers:
  - name: curl
    image: curlimages/curl:8.10.1
    command: ["sleep", "86400"]
EOF

echo "Setup completed for MHagou-003 Question 7 (namespaces restricted-zone and legacy-zone)"
exit 0
