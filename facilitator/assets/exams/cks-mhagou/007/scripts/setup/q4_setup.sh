#!/bin/bash

# Setup for MHAGOU-007 Question 4: SBOM of the image of a running Pod (trivy).
# Namespace sbom-lab is exclusive: Pod kiwi (an old nginx image). Output directory on the jumphost.

source "$(dirname "$0")/../lib/wait-cluster.sh"

NS="sbom-lab"
DIR="/tmp/exam/mhagou-007-q4"
ensure_namespace "$NS"
kubectl delete pod kiwi -n "$NS" --ignore-not-found --now >/dev/null 2>&1

kubectl apply -f - >/dev/null <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: kiwi
  namespace: ${NS}
  labels: {app: kiwi}
spec:
  containers:
  - name: web
    image: nginx:1.21.6
EOF

mkdir -p "${DIR:?}"
rm -f "${DIR:?}"/*
kubectl wait --for=condition=Ready pod/kiwi -n "$NS" --timeout=240s >/dev/null || { echo "WARNING: kiwi is not ready"; exit 1; }

echo "Setup completed for MHAGOU-007 Question 4 (namespace '$NS', output directory $DIR)"
exit 0
