#!/bin/bash
# Item: by behaviour, the Pods of testing cannot connect to anything (egress blocked, DNS included)

OUT_IP=$(kubectl get pod outsider -n testing-ext -o jsonpath='{.status.podIP}' 2>/dev/null)
[ -n "$OUT_IP" ] || { echo "❌ Pod outsider has no IP"; exit 1; }
reach() { kubectl exec -n testing "$1" -- wget -q -T 3 -O /dev/null "http://$2:80" >/dev/null 2>&1; }

for i in $(seq 1 12); do
  reach client "$OUT_IP" || break
  sleep 3
done

reach client "$OUT_IP" && { echo "❌ testing/client can still open a connection to a Pod of another namespace"; exit 1; }
if kubectl exec -n testing client -- nslookup -timeout=3 kubernetes.default.svc.cluster.local >/dev/null 2>&1; then
  echo "❌ testing/client can still resolve DNS names: egress is not fully blocked"
  exit 1
fi

echo "✅ Egress from the Pods of testing is blocked"
exit 0
