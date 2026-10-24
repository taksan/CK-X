#!/bin/bash

source "$(dirname "$0")/../lib/wait-cluster.sh"

ensure_namespace testing

kubectl delete networkpolicy deny-all -n testing 2>/dev/null || true

kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: test-pod
  namespace: testing
spec:
  containers:
  - name: busybox
    image: busybox
    command: ["sleep", "3600"]
EOF

echo "Setup completed for CKS-002 Question 1"
exit 0
