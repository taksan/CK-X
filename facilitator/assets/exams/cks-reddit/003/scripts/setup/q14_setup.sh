#!/bin/bash

# Setup for CKS-003 Question 14: RBAC. Namespace security is exclusive to this question.
#
# sa-dev-1 (used by web-pod) is bound to a Role that is far too broad; sa-ops has a Role
# of its own that must stay as it is (editing the wrong Role must be noticed).

source "$(dirname "$0")/../lib/wait-cluster.sh"

NAMESPACE="security"

ensure_namespace "$NAMESPACE"

kubectl delete pod web-pod -n "$NAMESPACE" --ignore-not-found >/dev/null 2>&1
kubectl delete clusterrolebinding role-2-binding --ignore-not-found >/dev/null 2>&1
kubectl delete clusterrole role-2 --ignore-not-found >/dev/null 2>&1

kubectl apply -f - <<EOF
apiVersion: v1
kind: ServiceAccount
metadata:
  name: sa-dev-1
  namespace: ${NAMESPACE}
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: sa-ops
  namespace: ${NAMESPACE}
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: dev-access
  namespace: ${NAMESPACE}
rules:
- apiGroups: [""]
  resources: ["services"]
  verbs: ["get", "list", "watch", "create", "delete"]
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["get", "list"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: dev-access-binding
  namespace: ${NAMESPACE}
subjects:
- kind: ServiceAccount
  name: sa-dev-1
  namespace: ${NAMESPACE}
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: dev-access
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: ops-access
  namespace: ${NAMESPACE}
rules:
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["get", "list", "delete"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: ops-access-binding
  namespace: ${NAMESPACE}
subjects:
- kind: ServiceAccount
  name: sa-ops
  namespace: ${NAMESPACE}
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: ops-access
---
apiVersion: v1
kind: Pod
metadata:
  name: web-pod
  namespace: ${NAMESPACE}
spec:
  serviceAccountName: sa-dev-1
  containers:
  - name: web
    image: nginx:1.27-alpine
EOF

echo "Setup completed for CKS-003 Question 14 (namespace '$NAMESPACE')"
exit 0
