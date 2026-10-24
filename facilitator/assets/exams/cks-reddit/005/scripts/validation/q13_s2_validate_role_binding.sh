#!/bin/bash
# Validate by behaviour that the ServiceAccount of nginx-pod can get, list and watch Deployments
# in test-system only, through a RoleBinding (not a ClusterRoleBinding), and nothing more

NS="test-system"
SA=$(kubectl get pod nginx-pod -n "$NS" -o jsonpath='{.spec.serviceAccountName}' 2>/dev/null)
[ -n "$SA" ] || { echo "❌ Pod nginx-pod not found"; exit 1; }
WHO="system:serviceaccount:$NS:$SA"
can() { kubectl auth can-i "$@" --as="$WHO" 2>/dev/null; }

for verb in get list watch; do
  [ "$(can $verb deployments.apps -n $NS)" = "yes" ] || { echo "❌ $SA cannot $verb deployments in $NS"; exit 1; }
done
for verb in create delete update; do
  [ "$(can $verb deployments.apps -n $NS)" = "no" ] || { echo "❌ $SA can also $verb deployments: only get, list and watch are allowed"; exit 1; }
done
[ "$(can list deployments.apps -n kube-system)" = "no" ] || { echo "❌ $SA can list deployments in other namespaces: use a Role and a RoleBinding"; exit 1; }
[ "$(can get secrets -n $NS)" = "no" ] || { echo "❌ $SA can read secrets"; exit 1; }
[ "$(kubectl auth can-i get deployments.apps -n $NS --as=system:serviceaccount:$NS:sa-dev-2 2>/dev/null)" = "no" ] || { echo "❌ The decoy ServiceAccount sa-dev-2 got the permissions too"; exit 1; }

echo "✅ $SA can get, list and watch Deployments in $NS only"
exit 0
