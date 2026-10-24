#!/bin/bash
# Validate by behaviour: the Role bound to web-sa before only allows get on pods

NS="database"
SA="system:serviceaccount:$NS:web-sa"
can() { kubectl auth can-i "$@" --as="$SA" -n "$NS" 2>/dev/null; }

kubectl get role web-access -n "$NS" >/dev/null 2>&1 || { echo "❌ Role 'web-access' was deleted: it must be restricted, not removed"; exit 1; }

# the permissions granted by the old Role alone (the new Role only grants update on statefulsets)
RULES=$(kubectl get role web-access -n "$NS" -o json | jq -c '[.rules[] | {r: .resources, v: .verbs}]')
echo "$RULES" | jq -e 'length >= 1 and all(.[]; (.v == ["get"]) and (.r == ["pods"]))' >/dev/null \
  || { echo "❌ Role 'web-access' must allow only the verb get on pods (rules: $RULES)"; exit 1; }

[ "$(can get pods)" = "yes" ] || { echo "❌ web-sa cannot get pods"; exit 1; }
for v in list delete create; do
  [ "$(can $v pods)" = "no" ] || { echo "❌ web-sa can still $v pods"; exit 1; }
done
[ "$(can get secrets)" = "no" ] || { echo "❌ web-sa can still read secrets"; exit 1; }

echo "✅ web-access only allows get on pods"
exit 0
