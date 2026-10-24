#!/bin/bash

# Setup for MHagou-005 Question 4: block the cloud metadata address. Namespace metadata-protect is
# exclusive; the workload is the Pod metadata-client (label app=metadata-client).

source "$(dirname "$0")/../lib/wait-cluster.sh"

NS="metadata-protect"
ensure_namespace "$NS"
kubectl delete networkpolicy --all -n "$NS" >/dev/null 2>&1
kubectl delete pod metadata-client -n "$NS" --ignore-not-found --now >/dev/null 2>&1

kubectl apply -f - >/dev/null <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: metadata-client
  namespace: ${NS}
  labels:
    app: metadata-client
spec:
  automountServiceAccountToken: false
  containers:
  - name: client
    image: busybox:1.36.1
    command: ["sh", "-c", "exec sleep 2147483647"]
EOF
kubectl wait --for=condition=Ready pod/metadata-client -n "$NS" --timeout=180s >/dev/null 2>&1 || { echo "WARNING: the workload is not ready"; exit 1; }

echo "Setup completed for MHagou-005 Question 4 (namespace '$NS')"
exit 0
