#!/bin/bash
# The RoleBinding k8s-seminar-bind binds the Role k8s-seminar to the ServiceAccount seminar-sa

B=$(kubectl get rolebinding k8s-seminar-bind -n seminar -o json 2>/dev/null)
[ -n "$B" ] || { echo "❌ RoleBinding 'k8s-seminar-bind' not found in namespace 'seminar'"; exit 1; }

if ! echo "$B" | jq -e '.roleRef.kind == "Role" and .roleRef.name == "k8s-seminar"' >/dev/null; then
  echo "❌ The RoleBinding must reference the Role 'k8s-seminar' (found $(echo "$B" | jq -r '.roleRef.kind + "/" + .roleRef.name'))"
  exit 1
fi
if ! echo "$B" | jq -e 'any(.subjects[]?; .kind == "ServiceAccount" and .name == "seminar-sa" and (.namespace // "seminar") == "seminar")' >/dev/null; then
  echo "❌ The RoleBinding must bind the ServiceAccount seminar-sa of the namespace seminar"
  exit 1
fi

echo "✅ RoleBinding k8s-seminar-bind binds k8s-seminar to seminar-sa"
exit 0
