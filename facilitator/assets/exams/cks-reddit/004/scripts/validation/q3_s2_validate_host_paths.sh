#!/bin/bash
# Validate no workload of the ci-cd namespace mounts a path of the node

NS="ci-cd"

if kubectl get deployments -n "$NS" -o json | jq -e '[.items[] | select([.spec.template.spec.volumes[]? | select(.hostPath != null)] | length > 0)] | length > 0' >/dev/null; then
  echo "❌ A Deployment still mounts a hostPath volume"
  exit 1
fi

if kubectl get pods -n "$NS" -o json | jq -e '[.items[] | select(.metadata.deletionTimestamp == null) | select([.spec.volumes[]? | select(.hostPath != null)] | length > 0)] | length > 0' >/dev/null; then
  echo "❌ A running Pod still mounts a hostPath volume"
  exit 1
fi

echo "✅ No workload in '$NS' mounts a path of the node"
exit 0
