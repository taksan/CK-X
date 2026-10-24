#!/bin/bash
# Item: the ClusterRoleBinding system:anonymous was removed (and the API server is reachable with the admin credentials)

for i in $(seq 1 30); do kubectl get --raw /readyz >/dev/null 2>&1 && break; sleep 4; done
kubectl get --raw /readyz >/dev/null 2>&1 || { echo "❌ The API server is not ready"; exit 1; }

if kubectl get clusterrolebinding system:anonymous >/dev/null 2>&1; then
  echo "❌ The ClusterRoleBinding system:anonymous still exists"
  exit 1
fi

echo "✅ The ClusterRoleBinding system:anonymous was removed"
exit 0
