#!/bin/bash

# Setup for MHagou CKS exam 9, Question 3: reduce the permissions of a Role.
# Namespace database is exclusive. The Role test-role-1 (bound to test-sa) is far too broad.

source "$(dirname "$0")/../lib/wait-cluster.sh"

NS="database"
ensure_namespace "$NS"

kubectl delete pod web-pod -n "$NS" --ignore-not-found --now >/dev/null 2>&1
kubectl delete rolebinding test-role-1-binding test-role-2-binding -n "$NS" --ignore-not-found >/dev/null 2>&1
kubectl delete role test-role-1 test-role-2 -n "$NS" --ignore-not-found >/dev/null 2>&1

kubectl apply -f - >/dev/null <<EOF
apiVersion: v1
kind: ServiceAccount
metadata: {name: test-sa, namespace: ${NS}}
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata: {name: test-role-1, namespace: ${NS}}
rules:
- apiGroups: ["", "apps"]
  resources: ["pods", "secrets", "deployments", "statefulsets"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata: {name: test-role-1-binding, namespace: ${NS}}
subjects:
- {kind: ServiceAccount, name: test-sa, namespace: ${NS}}
roleRef: {apiGroup: rbac.authorization.k8s.io, kind: Role, name: test-role-1}
---
apiVersion: v1
kind: Pod
metadata: {name: web-pod, namespace: ${NS}}
spec:
  serviceAccountName: test-sa
  containers:
  - name: web
    image: nginx:stable-alpine
    resources:
      requests: {cpu: 10m, memory: 16Mi}
EOF

echo "Setup completed for MHagou exam 9 Question 3 (namespace '$NS')"
exit 0
