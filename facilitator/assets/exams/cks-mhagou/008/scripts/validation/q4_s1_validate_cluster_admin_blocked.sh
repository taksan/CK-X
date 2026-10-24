#!/bin/bash
# Item: ci-bot cannot bind itself to cluster-admin (neither with a ClusterRoleBinding nor with a
# RoleBinding in ci-cd): the server refuses the requests (server-side dry-run, nothing is created)

source "$(dirname "$0")/../lib/rbac-q4.sh"
kubectl get serviceaccount ci-bot -n "$Q4_NS" >/dev/null 2>&1 || { echo "❌ ServiceAccount ci-bot was deleted from namespace $Q4_NS"; exit 1; }

for kind in cluster namespace; do
  bind_forbidden "$kind" cluster-admin
  case $? in
    0) ;;
    1) echo "❌ ci-bot can still create a $([ "$kind" = cluster ] && echo ClusterRoleBinding || echo RoleBinding) to cluster-admin"; exit 1 ;;
    *) echo "❌ The request to bind ci-bot to cluster-admin failed for a reason other than 'forbidden'"; exit 1 ;;
  esac
done

echo "✅ ci-bot cannot bind itself to cluster-admin"
exit 0
