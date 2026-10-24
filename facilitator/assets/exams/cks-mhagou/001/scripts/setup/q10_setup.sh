#!/bin/bash

# Setup for MHagou-001 Question 10: ServiceAccount token as a projected volume.
# Namespace vault-lab is exclusive. The ServiceAccount vault-sa automounts its token and the Pod
# immutable-pod runs as root with a writable filesystem; the manifest is given as a file.

source "$(dirname "$0")/../lib/wait-cluster.sh"

NS="vault-lab"
DIR="/tmp/exam/mhagou-001-q10"

ensure_namespace "$NS"
kubectl delete pod immutable-pod -n "$NS" --ignore-not-found --now >/dev/null 2>&1
kubectl delete serviceaccount vault-sa -n "$NS" --ignore-not-found >/dev/null 2>&1

mkdir -p "${DIR:?}"
rm -f "${DIR:?}"/*
cat > "$DIR/strict-pod.yaml" <<EOF
apiVersion: v1
kind: ServiceAccount
metadata:
  name: vault-sa
  namespace: ${NS}
---
apiVersion: v1
kind: Pod
metadata:
  name: immutable-pod
  namespace: ${NS}
spec:
  serviceAccountName: vault-sa
  containers:
  - name: app
    image: busybox:1.36
    command: ["sleep", "3600"]
EOF

kubectl apply -f "$DIR/strict-pod.yaml" >/dev/null
echo "Setup completed for MHagou-001 Question 10 (namespace '$NS', manifest $DIR/strict-pod.yaml)"
exit 0
