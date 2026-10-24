#!/bin/bash

# Setup for MHAGOU-002 Question 8: audit logging for one namespace. The namespace test is exclusive
# to this question (it is the namespace to audit). The API server starts without audit flags (reset_apiserver_audit removes them when the cluster has some); the
# candidate writes /etc/kubernetes/test-audit.yaml and edits the kube-apiserver manifest. Both are
# put back by the node checkpoint restore, which also removes the log file.

source "$(dirname "$0")/../lib/wait-cluster.sh"
source "$(dirname "$0")/../lib/audit-reset.sh"

reset_apiserver_audit || exit 1

NS="test"
ensure_namespace "$NS"
kubectl delete pod witness -n "$NS" --ignore-not-found --now >/dev/null 2>&1

kubectl apply -f - >/dev/null <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: witness
  namespace: ${NS}
spec:
  containers:
  - name: main
    image: busybox:1.36.1
    command: ["sleep", "86400"]
EOF

echo "Setup completed for MHAGOU-002 Question 8 (namespace '$NS')"
exit 0
