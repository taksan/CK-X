#!/bin/bash
# Item (by behaviour): messenger cannot reach db, and its other traffic (to cache) still works

NS="team-azure"
DB=$(kubectl get pod db -n "$NS" -o jsonpath='{.status.podIP}' 2>/dev/null)
CACHE=$(kubectl get pod cache -n "$NS" -o jsonpath='{.status.podIP}' 2>/dev/null)
[ -n "$DB" ] && [ -n "$CACHE" ] || { echo "❌ The Pods db and cache are not running"; exit 1; }
get() { kubectl exec -n "$NS" messenger -- wget -q -T 3 -O /dev/null "http://$1:80" >/dev/null 2>&1; }

# Cilium needs a few seconds to enforce a new policy
for i in $(seq 1 10); do
  get "$DB" || break
  sleep 3
done

get "$DB" && { echo "❌ The Pod messenger still reaches the database Pod db"; exit 1; }
get "$CACHE" || { echo "❌ The Pod messenger can no longer reach the cache Pod: only the traffic to role=database must be denied"; exit 1; }

echo "✅ messenger is denied to db and still reaches cache"
exit 0
