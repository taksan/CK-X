#!/bin/bash

# Setup for CKS-005 Question 2: who can read Secrets? Namespace rbac-audit is exclusive.
# Access to secrets is granted in three different ways: a Role naming secrets (reader-sa),
# a wildcard Role (batch-sa) and the built-in ClusterRole "edit" through a RoleBinding (ops-sa).
# viewer-sa (built-in "view") and plain-sa cannot read secrets.

source "$(dirname "$0")/../lib/wait-cluster.sh"

NS="rbac-audit"
DIR="/tmp/exam/cks-005-q2"
ensure_namespace "$NS"

for r in rolebinding/reader-bind rolebinding/batch-bind rolebinding/ops-bind rolebinding/viewer-bind \
         role/reader-role role/batch-role role/ops-configmaps rolebinding/ops-configmaps-bind; do
  kubectl delete "$r" -n "$NS" --ignore-not-found >/dev/null 2>&1
done

kubectl apply -f - >/dev/null <<EOF
apiVersion: v1
kind: ServiceAccount
metadata: {name: reader-sa, namespace: ${NS}}
---
apiVersion: v1
kind: ServiceAccount
metadata: {name: batch-sa, namespace: ${NS}}
---
apiVersion: v1
kind: ServiceAccount
metadata: {name: ops-sa, namespace: ${NS}}
---
apiVersion: v1
kind: ServiceAccount
metadata: {name: viewer-sa, namespace: ${NS}}
---
apiVersion: v1
kind: ServiceAccount
metadata: {name: plain-sa, namespace: ${NS}}
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata: {name: reader-role, namespace: ${NS}}
rules:
- apiGroups: [""]
  resources: ["secrets", "configmaps"]
  verbs: ["get", "list"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata: {name: reader-bind, namespace: ${NS}}
subjects: [{kind: ServiceAccount, name: reader-sa, namespace: ${NS}}]
roleRef: {apiGroup: rbac.authorization.k8s.io, kind: Role, name: reader-role}
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata: {name: batch-role, namespace: ${NS}}
rules:
- apiGroups: ["*"]
  resources: ["*"]
  verbs: ["get", "list", "watch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata: {name: batch-bind, namespace: ${NS}}
subjects: [{kind: ServiceAccount, name: batch-sa, namespace: ${NS}}]
roleRef: {apiGroup: rbac.authorization.k8s.io, kind: Role, name: batch-role}
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata: {name: ops-bind, namespace: ${NS}}
subjects: [{kind: ServiceAccount, name: ops-sa, namespace: ${NS}}]
roleRef: {apiGroup: rbac.authorization.k8s.io, kind: ClusterRole, name: edit}
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata: {name: viewer-bind, namespace: ${NS}}
subjects: [{kind: ServiceAccount, name: viewer-sa, namespace: ${NS}}]
roleRef: {apiGroup: rbac.authorization.k8s.io, kind: ClusterRole, name: view}
EOF

mkdir -p "${DIR:?}"
rm -f "${DIR:?}"/*
echo "Setup completed for CKS-005 Question 2 (namespace '$NS', output directory $DIR)"
exit 0
