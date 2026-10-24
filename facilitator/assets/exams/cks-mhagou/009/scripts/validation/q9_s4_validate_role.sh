#!/bin/bash
# Item: Role john-role in namespace john grants list on pods and secrets

NS="john"
R=$(kubectl get role john-role -n "$NS" -o json 2>/dev/null)
[ -n "$R" ] || { echo "❌ Role john-role not found in namespace $NS"; exit 1; }

for res in pods secrets; do
  echo "$R" | jq -e --arg r "$res" '[.rules[]? | select(((.apiGroups // []) | index("") != null or index("*") != null) and ((.verbs // []) | index("list") != null or index("*") != null) and ((.resources // []) | index($r) != null or index("*") != null) and ((.resourceNames // []) | length == 0))] | length > 0' >/dev/null \
    || { echo "❌ Role john-role does not grant list on $res (without resourceNames restriction)"; exit 1; }
done

echo "✅ Role john-role grants list on pods and secrets"
exit 0
