#!/bin/bash

# Setup for MHagou-003 Question 6: mesh-wide STRICT mTLS (Istio).
# Namespaces (exclusive): hello-mesh (the service, sidecar injection enabled), mesh-client (a client
# WITHOUT injection) and mesh-plain (a plain client the validators use to prove that plaintext is
# rejected). No PeerAuthentication exists.

source "$(dirname "$0")/../lib/wait-cluster.sh"

ensure_namespace hello-mesh
ensure_namespace mesh-client
ensure_namespace mesh-plain
kubectl label namespace hello-mesh istio-injection=enabled --overwrite >/dev/null
kubectl label namespace mesh-client istio-injection=disabled --overwrite >/dev/null
kubectl label namespace mesh-plain istio-injection=disabled --overwrite >/dev/null
kubectl delete peerauthentication --all -n istio-system --ignore-not-found >/dev/null 2>&1 || true
kubectl delete pod client -n mesh-client --ignore-not-found --now >/dev/null 2>&1
kubectl delete pod plain -n mesh-plain --ignore-not-found --now >/dev/null 2>&1

kubectl apply -f - >/dev/null <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: helloworld
  namespace: hello-mesh
spec:
  replicas: 1
  selector:
    matchLabels: {app: helloworld}
  template:
    metadata:
      labels: {app: helloworld}
    spec:
      containers:
      - name: hello
        image: hashicorp/http-echo:1.0
        args: ["-text=hello", "-listen=:5000"]
        ports: [{containerPort: 5000}]
---
apiVersion: v1
kind: Service
metadata:
  name: helloworld
  namespace: hello-mesh
spec:
  selector: {app: helloworld}
  ports: [{name: http, port: 5000, targetPort: 5000}]
---
apiVersion: v1
kind: Pod
metadata:
  name: client
  namespace: mesh-client
spec:
  containers:
  - name: curl
    image: curlimages/curl:8.10.1
    command: ["sleep", "86400"]
---
apiVersion: v1
kind: Pod
metadata:
  name: plain
  namespace: mesh-plain
spec:
  containers:
  - name: curl
    image: curlimages/curl:8.10.1
    command: ["sleep", "86400"]
EOF

echo "Setup completed for MHagou-003 Question 6 (namespaces hello-mesh, mesh-client, mesh-plain)"
exit 0
