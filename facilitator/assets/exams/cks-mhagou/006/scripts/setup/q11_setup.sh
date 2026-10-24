#!/bin/bash

# Setup for MHagou-006 Question 11: Pod Security Standards. Namespace pss-test is exclusive; it is
# created without Pod Security labels.

source "$(dirname "$0")/../lib/wait-cluster.sh"

ensure_namespace pss-test
kubectl label namespace pss-test pod-security.kubernetes.io/enforce- pod-security.kubernetes.io/warn- pod-security.kubernetes.io/audit- >/dev/null 2>&1 || true
kubectl delete pod test-pod -n pss-test --ignore-not-found --now >/dev/null 2>&1

mkdir -p /tmp/exam/mhagou-006-q11
cat > /tmp/exam/mhagou-006-q11/test-pod.yaml <<'YAML'
apiVersion: v1
kind: Pod
metadata:
  name: test-pod
  namespace: pss-test
spec:
  containers:
  - name: nginx
    image: nginx
YAML

echo "Setup completed for MHagou-006 Question 11 (namespace pss-test)"
exit 0
