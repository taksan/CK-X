#!/bin/bash
# Behaviour: the Pod app1 can no longer reach the Pod manage1 (HTTP port 80)

M=$(kubectl get pod manage1 -n manage -o jsonpath='{.status.podIP}' 2>/dev/null)
[ -n "$M" ] || { echo "❌ Pod manage1 has no IP"; exit 1; }
reach() { kubectl exec -n app app1 -- wget -q -T 4 -O /dev/null "http://$1" >/dev/null 2>&1; }

for i in $(seq 1 12); do
  reach "$M" || break
  sleep 3
done
reach "$M" && { echo "❌ app1 still reaches manage1 ($M): the egress of the namespace app must be limited to the data Pods"; exit 1; }

echo "✅ app1 cannot reach manage1"
exit 0
