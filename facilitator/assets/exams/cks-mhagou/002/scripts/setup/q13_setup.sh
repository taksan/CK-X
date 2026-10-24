#!/bin/bash

# Setup for MHAGOU-002 Question 13: deny all ingress and egress traffic of a namespace.
# Exclusive namespaces: lockdown (Pods server and client) and lockdown-ext (a Pod that tries to
# reach server from outside). The source task did not name the namespace: the question says lockdown.

source "$(dirname "$0")/../lib/wait-cluster.sh"

ensure_namespace lockdown
ensure_namespace lockdown-ext
kubectl delete networkpolicy all-deny -n lockdown --ignore-not-found >/dev/null 2>&1

kubectl apply -f - >/dev/null <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: server
  namespace: lockdown
  labels: {app: server}
spec:
  containers:
  - {name: nginx, image: "nginx:1.27-alpine", ports: [{containerPort: 80}]}
---
apiVersion: v1
kind: Pod
metadata:
  name: client
  namespace: lockdown
  labels: {app: client}
spec:
  containers:
  - {name: c, image: "busybox:1.36.1", command: ["sleep", "86400"]}
---
apiVersion: v1
kind: Pod
metadata:
  name: outsider
  namespace: lockdown-ext
  labels: {app: outsider}
spec:
  containers:
  - {name: c, image: "busybox:1.36.1", command: ["sleep", "86400"]}
EOF

echo "Setup completed for MHAGOU-002 Question 13 (namespaces lockdown and lockdown-ext)"
exit 0
