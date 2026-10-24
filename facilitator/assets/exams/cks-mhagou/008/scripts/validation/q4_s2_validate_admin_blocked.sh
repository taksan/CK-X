#!/bin/bash
# Item: ci-bot cannot bind itself to the role admin (ClusterRoleBinding or RoleBinding in ci-cd)

source "$(dirname "$0")/../lib/rbac-q4.sh"
kubectl get serviceaccount ci-bot -n "$Q4_NS" >/dev/null 2>&1 || { echo "❌ ServiceAccount ci-bot was deleted from namespace $Q4_NS"; exit 1; }

for kind in cluster namespace; do
  bind_forbidden "$kind" admin
  case $? in
    0) ;;
    1) echo "❌ ci-bot can still create a $([ "$kind" = cluster ] && echo ClusterRoleBinding || echo RoleBinding) to admin"; exit 1 ;;
    *) echo "❌ The request to bind ci-bot to admin failed for a reason other than 'forbidden'"; exit 1 ;;
  esac
done

echo "✅ ci-bot cannot bind itself to admin"
exit 0
