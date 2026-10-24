#!/bin/bash

# Setup for MHagou-003 Question 5: improve a Pod manifest with kubesec.
# Namespace kubesec-lab is exclusive. The manifest of a plain Pod is at /tmp/exam/mhagou-003-q5/pod.yaml
# on the jumphost (kubesec score 0); the image can run as a non-root user with a read-only root
# filesystem as long as /tmp is writable.

source "$(dirname "$0")/../lib/wait-cluster.sh"

NS="kubesec-lab"
DIR="/tmp/exam/mhagou-003-q5"
ensure_namespace "$NS"
kubectl delete pod web -n "$NS" --ignore-not-found --now >/dev/null 2>&1

mkdir -p "${DIR:?}"
rm -f "${DIR:?}"/*
cat > "$DIR/pod.yaml" <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: web
  namespace: ${NS}
  labels:
    run: web
spec:
  containers:
  - name: web
    image: nginxinc/nginx-unprivileged:1.27-alpine
    ports:
    - containerPort: 8080
EOF

echo "Setup completed for MHagou-003 Question 5 (namespace '$NS', manifest $DIR/pod.yaml)"
exit 0
