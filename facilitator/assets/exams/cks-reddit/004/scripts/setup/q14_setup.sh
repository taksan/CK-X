#!/bin/bash

# Setup for CKS-004 Question 14: least privilege RBAC. Namespace database is exclusive.
# web-sa is bound to the over-permissive Role web-access; audit-sa/audit-access is a decoy
# that must not be touched.

source "$(dirname "$0")/../lib/wait-cluster.sh"

NS="database"
ensure_namespace "$NS"

kubectl delete pod web-pod -n "$NS" --ignore-not-found --now >/dev/null 2>&1
kubectl delete rolebinding web-access-bind web-sts-updater-bind audit-access-bind -n "$NS" --ignore-not-found >/dev/null 2>&1
kubectl delete role web-access web-sts-updater audit-access -n "$NS" --ignore-not-found >/dev/null 2>&1
kubectl delete sa web-sa audit-sa -n "$NS" --ignore-not-found >/dev/null 2>&1

kubectl apply -f - >/dev/null <<EOF
apiVersion: v1
kind: ServiceAccount
metadata: {name: web-sa, namespace: ${NS}}
---
apiVersion: v1
kind: ServiceAccount
metadata: {name: audit-sa, namespace: ${NS}}
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata: {name: web-access, namespace: ${NS}}
rules:
- apiGroups: [""]
  resources: ["pods", "secrets", "configmaps"]
  verbs: ["get", "list", "watch", "create", "delete"]
- apiGroups: ["apps"]
  resources: ["statefulsets", "deployments"]
  verbs: ["get", "list", "update", "delete"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata: {name: web-access-bind, namespace: ${NS}}
subjects:
- {kind: ServiceAccount, name: web-sa, namespace: ${NS}}
roleRef: {apiGroup: rbac.authorization.k8s.io, kind: Role, name: web-access}
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata: {name: audit-access, namespace: ${NS}}
rules:
- apiGroups: [""]
  resources: ["pods", "events"]
  verbs: ["get", "list", "watch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata: {name: audit-access-bind, namespace: ${NS}}
subjects:
- {kind: ServiceAccount, name: audit-sa, namespace: ${NS}}
roleRef: {apiGroup: rbac.authorization.k8s.io, kind: Role, name: audit-access}
---
apiVersion: v1
kind: Pod
metadata: {name: web-pod, namespace: ${NS}}
spec:
  serviceAccountName: web-sa
  containers:
  - {name: web, image: busybox:1.36.1, command: [sleep, "86400"]}
EOF

echo "Setup completed for CKS-004 Question 14 (namespace '$NS')"
exit 0
