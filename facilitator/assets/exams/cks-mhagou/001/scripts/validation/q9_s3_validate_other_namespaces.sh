#!/bin/bash
# Item (by behaviour): every Pod of prod-yx13cs reaches redis-backend on 6379, the Pods of another namespace do not

NS="prod-x12cs"
IP=$(kubectl get pod redis-backend -n "$NS" -o jsonpath='{.status.podIP}' 2>/dev/null)
[ -n "$IP" ] || { echo "❌ Pod redis-backend has no IP"; exit 1; }
reach() { kubectl exec -n "$1" "$2" -- wget -q -T 3 -O /dev/null "http://$IP:$3" >/dev/null 2>&1; }

for i in $(seq 1 10); do
  reach prod-zz14cs stranger 6379 || break
  sleep 3
done

reach prod-zz14cs stranger 6379 && { echo "❌ A Pod of the namespace prod-zz14cs reaches redis-backend: only prod-yx13cs may"; exit 1; }
reach prod-yx13cs partner-client 6379 || { echo "❌ The Pods of the namespace prod-yx13cs cannot reach redis-backend on 6379 (use the existing label of the namespace)"; exit 1; }

echo "✅ prod-yx13cs reaches redis-backend, other namespaces do not"
exit 0
