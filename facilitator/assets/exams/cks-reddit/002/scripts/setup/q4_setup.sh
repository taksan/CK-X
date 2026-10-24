#!/bin/bash

# Setup for Question 4: Stateless and immutable Pods in the prod namespace
#
# Five Pods with neutral names. Two are compliant (and must be kept); three break
# "stateless" or "immutable" in ways that need the Pod spec to be read:
#   report-worker    emptyDir volume (stateful) although the root fs is read-only
#   batch-runner     privileged container
#   payments-api     good main container, but a sidecar with a writable root fs
# checkout mounts a ConfigMap: config-style volumes are not stateful.

source "$(dirname "$0")/../lib/wait-cluster.sh"

NAMESPACE="prod"

ensure_namespace "$NAMESPACE"

# Pods of previous versions of this question
kubectl delete pod stateful-pod privileged-pod immutable-pod auth-service inventory-sync gateway -n "$NAMESPACE" --ignore-not-found --wait=false >/dev/null 2>&1 || true

kubectl apply -f - <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config
  namespace: ${NAMESPACE}
data:
  mode: production
---
apiVersion: v1
kind: Pod
metadata:
  name: catalog-api
  namespace: ${NAMESPACE}
spec:
  containers:
  - name: app
    image: busybox:1.36.1
    command: ["sh", "-c", "sleep 3600"]
    securityContext:
      runAsNonRoot: true
      runAsUser: 1000
      readOnlyRootFilesystem: true
      privileged: false
---
apiVersion: v1
kind: Pod
metadata:
  name: checkout
  namespace: ${NAMESPACE}
spec:
  containers:
  - name: app
    image: busybox:1.36.1
    command: ["sh", "-c", "sleep 3600"]
    securityContext:
      runAsNonRoot: true
      runAsUser: 1000
      readOnlyRootFilesystem: true
    volumeMounts:
    - name: config
      mountPath: /etc/app
      readOnly: true
  volumes:
  - name: config
    configMap:
      name: app-config
---
apiVersion: v1
kind: Pod
metadata:
  name: report-worker
  namespace: ${NAMESPACE}
spec:
  containers:
  - name: app
    image: busybox:1.36.1
    command: ["sh", "-c", "sleep 3600"]
    securityContext:
      runAsNonRoot: true
      runAsUser: 1000
      readOnlyRootFilesystem: true
    volumeMounts:
    - name: work
      mountPath: /work
  volumes:
  - name: work
    emptyDir: {}
---
apiVersion: v1
kind: Pod
metadata:
  name: batch-runner
  namespace: ${NAMESPACE}
spec:
  containers:
  - name: app
    image: busybox:1.36.1
    command: ["sh", "-c", "sleep 3600"]
    securityContext:
      privileged: true
      readOnlyRootFilesystem: true
---
apiVersion: v1
kind: Pod
metadata:
  name: payments-api
  namespace: ${NAMESPACE}
spec:
  containers:
  - name: api
    image: busybox:1.36.1
    command: ["sh", "-c", "sleep 3600"]
    securityContext:
      runAsNonRoot: true
      runAsUser: 1000
      readOnlyRootFilesystem: true
  - name: log-shipper
    image: busybox:1.36.1
    command: ["sh", "-c", "sleep 3600"]
    securityContext:
      runAsUser: 1000
      readOnlyRootFilesystem: false
EOF

echo "Setup completed for CKS-002 Question 4 in namespace '$NAMESPACE'"
exit 0
