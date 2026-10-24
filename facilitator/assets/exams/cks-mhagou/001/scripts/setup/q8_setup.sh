#!/bin/bash

# Setup for MHagou-001 Question 8 (replaces the source task kubeadm-upgrade, which cannot run on
# this cluster): RBAC least privilege. Namespace release-lab is exclusive.
# The ServiceAccount release-bot is bound to a Role that allows everything in the namespace.
# audit-bot (another ServiceAccount, own Role) must stay untouched.

source "$(dirname "$0")/../lib/wait-cluster.sh"

NS="release-lab"
ensure_namespace "$NS"
kubectl delete rolebinding release-bind audit-bind -n "$NS" --ignore-not-found >/dev/null 2>&1
kubectl delete role release-role audit-role -n "$NS" --ignore-not-found >/dev/null 2>&1

kubectl apply -f - >/dev/null <<EOF
apiVersion: v1
kind: ServiceAccount
metadata: {name: release-bot, namespace: ${NS}}
---
apiVersion: v1
kind: ServiceAccount
metadata: {name: audit-bot, namespace: ${NS}}
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata: {name: release-role, namespace: ${NS}}
rules:
- apiGroups: ["*"]
  resources: ["*"]
  verbs: ["*"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata: {name: release-bind, namespace: ${NS}}
subjects:
- {kind: ServiceAccount, name: release-bot, namespace: ${NS}}
roleRef: {apiGroup: rbac.authorization.k8s.io, kind: Role, name: release-role}
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata: {name: audit-role, namespace: ${NS}}
rules:
- apiGroups: [""]
  resources: ["pods", "events"]
  verbs: ["get", "list", "watch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata: {name: audit-bind, namespace: ${NS}}
subjects:
- {kind: ServiceAccount, name: audit-bot, namespace: ${NS}}
roleRef: {apiGroup: rbac.authorization.k8s.io, kind: Role, name: audit-role}
EOF

echo "Setup completed for MHagou-001 Question 8 (namespace '$NS')"
exit 0
