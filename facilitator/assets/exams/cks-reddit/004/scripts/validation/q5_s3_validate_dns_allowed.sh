#!/bin/bash
# Validate that DNS still works while egress is denied (the denial itself must be in place)

NS="egress-lab"

SERVER=$(kubectl get pod server -n "$NS" -o jsonpath='{.status.podIP}' 2>/dev/null)
for i in $(seq 1 10); do
  kubectl exec -n "$NS" client -- wget -q -T 3 -O /dev/null "http://$SERVER" >/dev/null 2>&1 || break
  sleep 3
done
if kubectl exec -n "$NS" client -- wget -q -T 3 -O /dev/null "http://$SERVER" >/dev/null 2>&1; then
  echo "❌ Egress is not denied (the client still reaches the server Pod)"
  exit 1
fi

# a DNS rule takes a few seconds to be enforced too
OK=""
for i in $(seq 1 10); do
  kubectl exec -n "$NS" client -- nslookup kubernetes.default.svc.cluster.local >/dev/null 2>&1 && { OK=yes; break; }
  sleep 3
done
if [ -z "$OK" ]; then
  echo "❌ DNS lookups fail: allow egress to the cluster DNS (port 53, UDP and TCP)"
  exit 1
fi

echo "✅ Egress is denied but DNS lookups work"
exit 0
