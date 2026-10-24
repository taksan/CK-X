#!/bin/bash
# Item (by behaviour): in prod-x12cs only the Pods labelled backend=prod-x12cs reach redis-backend on 6379

NS="prod-x12cs"
IP=$(kubectl get pod redis-backend -n "$NS" -o jsonpath='{.status.podIP}' 2>/dev/null)
[ -n "$IP" ] || { echo "❌ Pod redis-backend has no IP"; exit 1; }
reach() { kubectl exec -n "$1" "$2" -- wget -q -T 3 -O /dev/null "http://$IP:$3" >/dev/null 2>&1; }

# the policy needs a few seconds to be enforced: wait until the unlabelled Pod is blocked (or give up)
for i in $(seq 1 10); do
  reach "$NS" batch-worker 6379 || break
  sleep 3
done

reach "$NS" batch-worker 6379 && { echo "❌ The unlabelled Pod batch-worker of prod-x12cs still reaches redis-backend on 6379"; exit 1; }
reach "$NS" app-worker 6379 || { echo "❌ The Pod app-worker (label backend=prod-x12cs) cannot reach redis-backend on 6379"; exit 1; }

echo "✅ Only the Pods labelled backend=prod-x12cs reach redis-backend from prod-x12cs"
exit 0
