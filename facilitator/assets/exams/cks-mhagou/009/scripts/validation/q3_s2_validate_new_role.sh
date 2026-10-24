#!/bin/bash
# Item: Role test-role-2 exists in database and allows only update on statefulsets

NS="database"
R=$(kubectl get role test-role-2 -n "$NS" -o json 2>/dev/null)
[ -n "$R" ] || { echo "❌ Role test-role-2 not found in namespace $NS"; exit 1; }

echo "$R" | jq -e '(.rules | length) > 0 and all(.rules[]; ((.apiGroups // []) == ["apps"]) and ((.resources // []) == ["statefulsets"]) and ((.verbs // []) == ["update"]))' >/dev/null \
  || { echo "❌ Role test-role-2 must allow only update on statefulsets of the apps group (rules: $(echo "$R" | jq -c '[.rules[] | {g: .apiGroups, r: .resources, v: .verbs}]'))"; exit 1; }

echo "✅ test-role-2 allows only update on statefulsets"
exit 0
