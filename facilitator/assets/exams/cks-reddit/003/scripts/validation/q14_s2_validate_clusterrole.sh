#!/bin/bash
# Validate ClusterRole role-2 (only update on namespaces) and ClusterRoleBinding role-2-binding

NS="security"
SA="system:serviceaccount:$NS:sa-dev-1"

JSON=$(kubectl get clusterrole role-2 -o json 2>/dev/null)
if [ -z "$JSON" ]; then
  echo "❌ ClusterRole 'role-2' not found"
  exit 1
fi

RULES=$(echo "$JSON" | jq -c '{verbs: ([.rules[]?.verbs[]?] | unique), resources: ([.rules[]?.resources[]?] | unique)}')
if [ "$RULES" != '{"verbs":["update"],"resources":["namespaces"]}' ]; then
  echo "❌ ClusterRole 'role-2' must allow only the verb update on the resource namespaces (found: $RULES)"
  exit 1
fi

if ! kubectl get clusterrolebinding role-2-binding -o json 2>/dev/null | jq -e --arg ns "$NS" '
    .roleRef.kind == "ClusterRole" and .roleRef.name == "role-2"
    and ([.subjects[]? | select(.kind == "ServiceAccount" and .name == "sa-dev-1" and .namespace == $ns)] | length > 0)' >/dev/null; then
  echo "❌ ClusterRoleBinding 'role-2-binding' does not bind 'role-2' to the ServiceAccount security/sa-dev-1"
  exit 1
fi

if [ "$(kubectl auth can-i update namespaces --as "$SA" 2>/dev/null)" != "yes" ]; then
  echo "❌ sa-dev-1 cannot update namespaces"
  exit 1
fi

for verb in get list delete create patch; do
  if [ "$(kubectl auth can-i "$verb" namespaces --as "$SA" 2>/dev/null)" = "yes" ]; then
    echo "❌ sa-dev-1 may $verb namespaces: only update is allowed"
    exit 1
  fi
done

echo "✅ sa-dev-1 can update namespaces and nothing else on them"
exit 0
