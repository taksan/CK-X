#!/bin/bash
# Item: release-bot is still bound to a Role of the namespace and no rule that applies to it uses a wildcard;
# the other ServiceAccount (audit-bot) was not touched

NS="release-lab"

BINDINGS=$(kubectl get rolebinding -n "$NS" -o json 2>/dev/null | jq -c '[.items[] | select(any(.subjects[]?; .kind == "ServiceAccount" and .name == "release-bot"))]')
[ "$(echo "$BINDINGS" | jq 'length')" -gt 0 ] || { echo "❌ release-bot is not bound to any Role anymore: it must keep the permissions that were requested"; exit 1; }

for role in $(echo "$BINDINGS" | jq -r '.[] | select(.roleRef.kind == "Role") | .roleRef.name'); do
  if kubectl get role "$role" -n "$NS" -o json 2>/dev/null | jq -e 'any(.rules[]?; (.verbs // []) + (.resources // []) + (.apiGroups // []) | index("*") != null)' >/dev/null; then
    echo "❌ The Role '$role' bound to release-bot still contains a wildcard (*) in verbs, resources or apiGroups"
    exit 1
  fi
done
if echo "$BINDINGS" | jq -e 'any(.[]; .roleRef.kind == "ClusterRole")' >/dev/null; then
  echo "❌ release-bot is bound to a ClusterRole: use a Role of the namespace"
  exit 1
fi

[ "$(kubectl auth can-i list pods --as=system:serviceaccount:$NS:audit-bot -n "$NS" 2>/dev/null)" = "yes" ] \
  && [ "$(kubectl auth can-i list events --as=system:serviceaccount:$NS:audit-bot -n "$NS" 2>/dev/null)" = "yes" ] \
  || { echo "❌ The permissions of audit-bot were changed: it was not part of the task"; exit 1; }

echo "✅ release-bot has no wildcard rule and audit-bot is untouched"
exit 0
