#!/bin/bash
# app-reader is bound with a namespaced RoleBinding to a namespaced Role (not a ClusterRole, no ClusterRoleBinding)

NS="rbac-minimize"
RB=$(kubectl get rolebinding -n "$NS" -o json 2>/dev/null)

MATCH=$(echo "$RB" | jq -r '[.items[] | select(any(.subjects[]?; .kind == "ServiceAccount" and .name == "app-reader" and ((.namespace // "'"$NS"'") == "'"$NS"'")))] | .[] | "\(.metadata.name) \(.roleRef.kind) \(.roleRef.name)"')
[ -n "$MATCH" ] || { echo "❌ No RoleBinding of $NS binds the ServiceAccount app-reader"; exit 1; }

if ! echo "$MATCH" | awk '$2 == "Role" {found=1} END {exit !found}'; then
  echo "❌ The RoleBinding refers to a ClusterRole ($MATCH): use a namespaced Role"
  exit 1
fi
ROLE=$(echo "$MATCH" | awk '$2 == "Role" {print $3; exit}')
kubectl get role "$ROLE" -n "$NS" >/dev/null 2>&1 || { echo "❌ The Role $ROLE referenced by the RoleBinding does not exist in $NS"; exit 1; }

CRB=$(kubectl get clusterrolebinding -o json 2>/dev/null | jq -r '[.items[] | select(any(.subjects[]?; .kind == "ServiceAccount" and .name == "app-reader" and .namespace == "'"$NS"'")) | .metadata.name] | join(",")')
[ -z "$CRB" ] || { echo "❌ app-reader is also bound cluster-wide by the ClusterRoleBinding $CRB"; exit 1; }

echo "✅ app-reader is bound by a RoleBinding to the namespaced Role $ROLE"
exit 0
