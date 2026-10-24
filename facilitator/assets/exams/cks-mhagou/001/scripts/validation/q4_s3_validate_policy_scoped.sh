#!/bin/bash
# Item (by behaviour): the deny is scoped to messenger: another Pod (reporter) still reaches db
# (credited only together with the block of messenger, so the untouched cluster does not pass)

NS="team-azure"
DB=$(kubectl get pod db -n "$NS" -o jsonpath='{.status.podIP}' 2>/dev/null)
[ -n "$DB" ] || { echo "❌ The Pod db is not running"; exit 1; }
get() { kubectl exec -n "$NS" "$1" -- wget -q -T 3 -O /dev/null "http://$DB:80" >/dev/null 2>&1; }

for i in $(seq 1 10); do
  get messenger || break
  sleep 3
done

get messenger && { echo "❌ messenger still reaches db: the policy is not in effect"; exit 1; }
get reporter || { echo "❌ The Pod reporter (role=reporting) cannot reach db: the deny must only apply to role=messenger"; exit 1; }

echo "✅ Only messenger is denied to db; reporter still reaches it"
exit 0
