#!/bin/bash

# Setup for MHAGOU-002 Question 12: ingress NetworkPolicy with a namespace and a pod selector.
# Exclusive namespaces: moon (target Pod nginx-pod plus a neighbour), hello (labelled ns=test, the
# allowed namespace), moon-ext-a (a Pod labelled app=backend: allowed), moon-ext-b (a Pod labelled
# app=frontend: denied).

source "$(dirname "$0")/../lib/wait-cluster.sh"

for ns in moon hello moon-ext-a moon-ext-b; do ensure_namespace "$ns"; done
kubectl label namespace hello ns=test --overwrite >/dev/null
kubectl label namespace moon-ext-a ns=partners --overwrite >/dev/null
kubectl label namespace moon-ext-b ns=others --overwrite >/dev/null
kubectl delete networkpolicy np-restriction -n moon --ignore-not-found >/dev/null 2>&1

kubectl apply -f - >/dev/null <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: nginx-pod
  namespace: moon
  labels: {run: nginx-pod}
spec:
  containers:
  - {name: nginx, image: "nginx:1.27-alpine", ports: [{containerPort: 80}]}
---
apiVersion: v1
kind: Pod
metadata:
  name: neighbor
  namespace: moon
  labels: {run: neighbor}
spec:
  containers:
  - {name: c, image: "busybox:1.36.1", command: ["sleep", "86400"]}
---
apiVersion: v1
kind: Pod
metadata:
  name: peer
  namespace: hello
  labels: {run: peer}
spec:
  containers:
  - {name: c, image: "busybox:1.36.1", command: ["sleep", "86400"]}
---
apiVersion: v1
kind: Pod
metadata:
  name: api-client
  namespace: moon-ext-a
  labels: {app: backend}
spec:
  containers:
  - {name: c, image: "busybox:1.36.1", command: ["sleep", "86400"]}
---
apiVersion: v1
kind: Pod
metadata:
  name: web-client
  namespace: moon-ext-b
  labels: {app: frontend}
spec:
  containers:
  - {name: c, image: "busybox:1.36.1", command: ["sleep", "86400"]}
EOF

echo "Setup completed for MHAGOU-002 Question 12 (namespaces moon, hello, moon-ext-a, moon-ext-b)"
exit 0
