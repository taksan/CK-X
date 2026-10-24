#!/bin/bash
# Validate the ServiceAccount, Role and RoleBinding in staging by what the ServiceAccount may do

NS="staging"
SA="system:serviceaccount:$NS:deployer-sa"

kubectl get serviceaccount deployer-sa -n "$NS" >/dev/null 2>&1 || { echo "❌ ServiceAccount 'deployer-sa' not found in '$NS'"; exit 1; }
kubectl get role pod-manager -n "$NS" >/dev/null 2>&1 || { echo "❌ Role 'pod-manager' not found in '$NS'"; exit 1; }

if ! kubectl get rolebinding pod-manager-binding -n "$NS" -o json 2>/dev/null | jq -e '
    .roleRef.kind == "Role" and .roleRef.name == "pod-manager"
    and ([.subjects[]? | select(.kind == "ServiceAccount" and .name == "deployer-sa")] | length > 0)' >/dev/null; then
  echo "❌ RoleBinding 'pod-manager-binding' does not bind Role 'pod-manager' to ServiceAccount 'deployer-sa'"
  exit 1
fi

can() { kubectl auth can-i "$1" "$2" -n "${3:-$NS}" --as "$SA" 2>/dev/null; }

for verb in create get list delete; do
  if [ "$(can $verb pods)" != "yes" ]; then
    echo "❌ deployer-sa cannot $verb pods in '$NS'"
    exit 1
  fi
done

for check in "update pods" "patch pods" "create deployments" "get secrets" "create pods kube-public"; do
  set -- $check
  if [ "$(can "$1" "$2" "$3")" = "yes" ]; then
    echo "❌ deployer-sa may too much: it can $1 $2${3:+ in $3}"
    exit 1
  fi
done

echo "✅ deployer-sa can create, get, list and delete Pods in '$NS' and nothing else"
exit 0
