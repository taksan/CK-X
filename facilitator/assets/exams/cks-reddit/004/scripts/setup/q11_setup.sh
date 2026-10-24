#!/bin/bash

# Setup for CKS-004 Question 11: ServiceAccount hygiene. Namespace web-team is exclusive.
# Pod "reporter" uses reporter-sa (in use). The Pod manifest references a ServiceAccount that does
# not exist. ServiceAccounts stale-account and old-bot are not used by any Pod.

source "$(dirname "$0")/../lib/wait-cluster.sh"

NS="web-team"
DIR="/tmp/exam/cks-004-q11"

ensure_namespace "$NS"
kubectl delete pod frontend reporter -n "$NS" --ignore-not-found --now >/dev/null 2>&1
for sa in frontend-sa reporter-sa stale-account old-bot frontend-svc; do
  kubectl delete sa "$sa" -n "$NS" --ignore-not-found >/dev/null 2>&1
done

kubectl create sa reporter-sa -n "$NS" >/dev/null
kubectl create sa stale-account -n "$NS" >/dev/null
kubectl create sa old-bot -n "$NS" >/dev/null
kubectl apply -f - >/dev/null <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: reporter
  namespace: ${NS}
spec:
  serviceAccountName: reporter-sa
  containers:
  - name: reporter
    image: busybox:1.36.1
    command: ["sleep", "86400"]
EOF

mkdir -p "${DIR:?}"
rm -f "${DIR:?}"/*
cat > "$DIR/pod-manifest.yaml" <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: frontend
  namespace: ${NS}
  labels:
    run: frontend
spec:
  serviceAccountName: frontend-svc
  containers:
  - name: frontend
    image: busybox:1.36.1
    command: ["sleep", "86400"]
EOF

echo "Setup completed for CKS-004 Question 11 (namespace '$NS', manifest $DIR/pod-manifest.yaml)"
exit 0
