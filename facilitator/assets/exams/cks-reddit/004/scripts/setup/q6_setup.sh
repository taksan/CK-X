#!/bin/bash

# Setup for CKS-004 Question 6: a ServiceAccount that cannot read secrets. Namespace qa is
# exclusive to this question.
#
# A RoleBinding gives the group system:serviceaccounts:qa (every ServiceAccount of the namespace,
# present and future) a Role that can read ConfigMaps and Secrets: a new ServiceAccount inherits
# the access to secrets. ci-bot is an existing ServiceAccount that needs the ConfigMap access.

source "$(dirname "$0")/../lib/wait-cluster.sh"

NAMESPACE="qa"
WORKDIR="/tmp/exam/cks-004-q6"

ensure_namespace "$NAMESPACE"

kubectl delete pod frontend -n "$NAMESPACE" --ignore-not-found --now >/dev/null 2>&1
kubectl delete serviceaccount backend-qa -n "$NAMESPACE" --ignore-not-found >/dev/null 2>&1

kubectl apply -f - <<EOF
apiVersion: v1
kind: ServiceAccount
metadata:
  name: ci-bot
  namespace: ${NAMESPACE}
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: shared-reader
  namespace: ${NAMESPACE}
rules:
- apiGroups: [""]
  resources: ["configmaps"]
  verbs: ["get", "list"]
- apiGroups: [""]
  resources: ["secrets"]
  verbs: ["get", "list"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: all-service-accounts
  namespace: ${NAMESPACE}
subjects:
- kind: Group
  name: system:serviceaccounts:${NAMESPACE}
  apiGroup: rbac.authorization.k8s.io
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: shared-reader
---
apiVersion: v1
kind: Pod
metadata:
  name: frontend
  namespace: ${NAMESPACE}
spec:
  containers:
  - name: frontend
    image: nginx:1.27-alpine
EOF

mkdir -p "${WORKDIR:?}"
cat > "$WORKDIR/frontend-pod.yaml" <<'MANIFEST'
apiVersion: v1
kind: Pod
metadata:
  name: frontend
  namespace: qa
spec:
  containers:
  - name: frontend
    image: nginx:1.27-alpine
MANIFEST

echo "Setup completed for CKS-004 Question 6 (namespace '$NAMESPACE', manifest in $WORKDIR)"
exit 0
