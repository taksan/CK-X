#!/bin/bash

# Setup for MHAGOU-007 Question 2: least privilege for the user jacob.
# Namespace dev-z is exclusive. jacob (an identity, no object needed) is bound to the Role
# dev-user-access, which allows every verb on pods. A secret and a configmap exist to read.

source "$(dirname "$0")/../lib/wait-cluster.sh"

NS="dev-z"
ensure_namespace "$NS"
kubectl delete rolebinding dev-user-binding -n "$NS" --ignore-not-found >/dev/null 2>&1
kubectl delete role dev-user-access -n "$NS" --ignore-not-found >/dev/null 2>&1

kubectl apply -f - >/dev/null <<EOF
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: dev-user-access
  namespace: ${NS}
rules:
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["*"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: dev-user-binding
  namespace: ${NS}
subjects:
- kind: User
  apiGroup: rbac.authorization.k8s.io
  name: jacob
roleRef:
  kind: Role
  apiGroup: rbac.authorization.k8s.io
  name: dev-user-access
EOF

echo "Setup completed for MHAGOU-007 Question 2 (namespace '$NS')"
exit 0
