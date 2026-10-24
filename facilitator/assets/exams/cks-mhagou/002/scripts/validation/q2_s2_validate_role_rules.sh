#!/bin/bash
# The Role k8s-seminar allows only the verbs create and update, only on pods and deployments

R=$(kubectl get role k8s-seminar -n seminar -o json 2>/dev/null)
[ -n "$R" ] || { echo "❌ Role 'k8s-seminar' not found in namespace 'seminar'"; exit 1; }

VERBS=$(echo "$R" | jq -r '[.rules[].verbs[]] | unique | join(",")')
RES=$(echo "$R" | jq -r '[.rules[].resources[]] | unique | join(",")')

if [ "$VERBS" != "create,update" ]; then
  echo "❌ The Role has the verbs '$VERBS', expected exactly create and update"
  exit 1
fi
if [ "$RES" != "deployments,pods" ]; then
  echo "❌ The Role covers the resources '$RES', expected exactly pods and deployments"
  exit 1
fi
# deployments live in the apps group, pods in the core group
if ! echo "$R" | jq -e '[.rules[] | select((.resources | index("deployments")) != null) | (.apiGroups // [])[]] | index("apps") != null' >/dev/null; then
  echo "❌ The resource 'deployments' must be in the apiGroup 'apps'"
  exit 1
fi

echo "✅ Role k8s-seminar: create and update on pods and deployments only"
exit 0
