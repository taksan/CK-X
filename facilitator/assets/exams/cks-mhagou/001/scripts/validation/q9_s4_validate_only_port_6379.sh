#!/bin/bash
# Item (by behaviour): allowed clients reach TCP 6379 only; the other port of the Pod (8080) stays closed

NS="prod-x12cs"
IP=$(kubectl get pod redis-backend -n "$NS" -o jsonpath='{.status.podIP}' 2>/dev/null)
[ -n "$IP" ] || { echo "❌ Pod redis-backend has no IP"; exit 1; }
reach() { kubectl exec -n "$1" "$2" -- wget -q -T 3 -O /dev/null "http://$IP:$3" >/dev/null 2>&1; }

for i in $(seq 1 10); do
  reach "$NS" app-worker 8080 || break
  sleep 3
done

reach "$NS" app-worker 8080 && { echo "❌ An allowed client reaches port 8080 of redis-backend: only TCP 6379 may be open"; exit 1; }
reach prod-yx13cs partner-client 8080 && { echo "❌ A Pod of prod-yx13cs reaches port 8080 of redis-backend: only TCP 6379 may be open"; exit 1; }
reach "$NS" app-worker 6379 || { echo "❌ The allowed client cannot reach port 6379 any more"; exit 1; }

echo "✅ Only TCP 6379 is open to the allowed clients"
exit 0
