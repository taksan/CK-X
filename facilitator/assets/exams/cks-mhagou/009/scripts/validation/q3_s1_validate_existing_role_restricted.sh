#!/bin/bash
# Item: the Role bound to the ServiceAccount of web-pod allows only get on pods

NS="database"
SA=$(kubectl get pod web-pod -n "$NS" -o jsonpath='{.spec.serviceAccountName}' 2>/dev/null)
[ -n "$SA" ] || { echo "❌ Pod web-pod not found in namespace $NS"; exit 1; }
WHO="system:serviceaccount:$NS:$SA"
can() { kubectl auth can-i "$@" --as="$WHO" -n "$NS" 2>/dev/null; }

# the Roles bound to the ServiceAccount through RoleBindings (any name)
ROLES=$(kubectl get rolebinding -n "$NS" -o json | jq -r --arg sa "$SA" '.items[] | select(.roleRef.kind == "Role" and any(.subjects[]?; .kind == "ServiceAccount" and .name == $sa)) | .roleRef.name' | sort -u)
echo "$ROLES" | grep -qx 'test-role-1' || { echo "❌ The Role test-role-1 is not bound to $SA any more (it had to be edited, not replaced)"; exit 1; }

R=$(kubectl get role test-role-1 -n "$NS" -o json 2>/dev/null)
[ -n "$R" ] || { echo "❌ Role test-role-1 was deleted: it had to be edited"; exit 1; }
echo "$R" | jq -e '(.rules | length) > 0 and all(.rules[]; ((.apiGroups // []) == [""]) and ((.resources // []) == ["pods"]) and ((.verbs // []) == ["get"]))' >/dev/null \
  || { echo "❌ Role test-role-1 must allow only the verb get on pods (rules: $(echo "$R" | jq -c '[.rules[] | {g: .apiGroups, r: .resources, v: .verbs}]'))"; exit 1; }

[ "$(can get pods)" = "yes" ] || { echo "❌ $SA cannot get pods any more"; exit 1; }
for what in "list pods" "delete pods" "get secrets" "create deployments.apps"; do
  [ "$(can $what)" = "no" ] || { echo "❌ $SA can still: $what"; exit 1; }
done

echo "✅ test-role-1 allows only get on pods"
exit 0
