#!/bin/bash
# Validate no ClusterRoleBinding grants permissions to the user system:anonymous
# (namespaced RoleBindings are left alone: kubeadm ships one that lets anonymous
# clients read the cluster-info ConfigMap in kube-public)

BINDINGS=$(kubectl get clusterrolebinding -o json 2>/dev/null | jq -r '
  .items[] | select(any(.subjects[]?; .name == "system:anonymous")) | .metadata.name')

if [ -n "$BINDINGS" ]; then
  echo "❌ These ClusterRoleBindings still grant access to system:anonymous:"
  echo "$BINDINGS" | sed 's/^/   /'
  exit 1
fi

echo "✅ No ClusterRoleBinding grants permissions to system:anonymous"
exit 0
