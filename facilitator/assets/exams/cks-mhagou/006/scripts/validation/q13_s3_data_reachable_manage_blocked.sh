#!/bin/bash
# Behaviour: app1 reaches data1 while manage1 is blocked (the policy allows what is asked and nothing else)

D=$(kubectl get pod data1 -n data -o jsonpath='{.status.podIP}' 2>/dev/null)
M=$(kubectl get pod manage1 -n manage -o jsonpath='{.status.podIP}' 2>/dev/null)
[ -n "$D" ] && [ -n "$M" ] || { echo "❌ Pods data1 or manage1 have no IP"; exit 1; }
reach() { kubectl exec -n app app1 -- wget -q -T 4 -O /dev/null "http://$1" >/dev/null 2>&1; }

for i in $(seq 1 12); do
  reach "$M" || break
  sleep 3
done
reach "$M" && { echo "❌ app1 still reaches manage1: the policy does not block it"; exit 1; }
reach "$D" || { echo "❌ app1 cannot reach data1 ($D): the policy must allow the traffic to the data Pods"; exit 1; }

echo "✅ app1 reaches data1 and cannot reach manage1"
exit 0
