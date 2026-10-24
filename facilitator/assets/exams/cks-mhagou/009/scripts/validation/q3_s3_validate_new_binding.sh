#!/bin/bash
# Item: test-role-2 is bound to the ServiceAccount of web-pod (a RoleBinding) and it works

NS="database"
SA=$(kubectl get pod web-pod -n "$NS" -o jsonpath='{.spec.serviceAccountName}' 2>/dev/null)
[ -n "$SA" ] || { echo "❌ Pod web-pod not found in namespace $NS"; exit 1; }
WHO="system:serviceaccount:$NS:$SA"

kubectl get role test-role-2 -n "$NS" >/dev/null 2>&1 || { echo "❌ Role test-role-2 does not exist yet"; exit 1; }

kubectl get rolebinding -n "$NS" -o json | jq -e --arg sa "$SA" '[.items[] | select(.roleRef.kind == "Role" and .roleRef.name == "test-role-2" and any(.subjects[]?; .kind == "ServiceAccount" and .name == $sa and ((.namespace // "database") == "database")))] | length > 0' >/dev/null \
  || { echo "❌ No RoleBinding binds Role test-role-2 to the ServiceAccount $SA"; exit 1; }

[ "$(kubectl auth can-i update statefulsets.apps --as="$WHO" -n "$NS" 2>/dev/null)" = "yes" ] || { echo "❌ $SA cannot update statefulsets"; exit 1; }
for verb in create delete patch get; do
  [ "$(kubectl auth can-i "$verb" statefulsets.apps --as="$WHO" -n "$NS" 2>/dev/null)" = "no" ] || { echo "❌ $SA can also $verb statefulsets"; exit 1; }
done

echo "✅ test-role-2 is bound to $SA and allows only update on statefulsets"
exit 0
