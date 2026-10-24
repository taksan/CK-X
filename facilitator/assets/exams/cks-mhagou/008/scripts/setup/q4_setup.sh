#!/bin/bash

# Setup for MHAGOU-008 Question 4: a ServiceAccount that can escalate through RBAC.
# Namespace ci-cd is exclusive. ServiceAccount ci-bot is bound through the ClusterRole ci-bot-role
# and the ClusterRoleBinding ci-bot-binding (cluster-scoped objects, removed by the session cleanup).
# The role lets ci-bot write (Cluster)RoleBindings and use the "bind" verb on roles and clusterroles.

source "$(dirname "$0")/../lib/wait-cluster.sh"

NS="ci-cd"
ensure_namespace "$NS"

kubectl delete clusterrolebinding ci-bot-binding --ignore-not-found >/dev/null 2>&1
kubectl delete clusterrole ci-bot-role --ignore-not-found >/dev/null 2>&1

kubectl apply -f - >/dev/null <<EOF
apiVersion: v1
kind: ServiceAccount
metadata:
  name: ci-bot
  namespace: ${NS}
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: ci-bot-role
rules:
- apiGroups: [""]
  resources: ["pods", "services", "configmaps"]
  verbs: ["get", "list", "watch", "create", "update", "delete"]
- apiGroups: ["apps"]
  resources: ["deployments", "replicasets"]
  verbs: ["get", "list", "watch", "create", "update", "delete"]
- apiGroups: ["rbac.authorization.k8s.io"]
  resources: ["clusterrolebindings", "rolebindings"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
- apiGroups: ["rbac.authorization.k8s.io"]
  resources: ["roles", "clusterroles"]
  verbs: ["bind"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: ci-bot-binding
subjects:
- kind: ServiceAccount
  name: ci-bot
  namespace: ${NS}
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: ci-bot-role
EOF

echo "Setup completed for MHAGOU-008 Question 4 (namespace '$NS')"
exit 0
