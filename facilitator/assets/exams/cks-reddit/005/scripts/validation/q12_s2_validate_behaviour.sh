#!/bin/bash
# Validate by behaviour: only the ServiceAccount frontend may call orders, and only with GET

NS="mesh-lab"
code() { kubectl exec -n "$NS" "$1" -c curl -- curl -s -o /dev/null -m 5 -w '%{http_code}' -X "$2" http://orders.mesh-lab.svc.cluster.local/ 2>/dev/null; }

for p in web-client batch-client; do
  kubectl get pod "$p" -n "$NS" -o jsonpath='{.status.containerStatuses[*].ready}' 2>/dev/null | grep -qv false || { echo "❌ Pod $p is not ready"; exit 1; }
done

# the policy needs a few seconds to reach the sidecars
for i in $(seq 1 15); do
  [ "$(code batch-client GET)" = "403" ] && break
  sleep 3
done

[ "$(code web-client GET)" = "200" ] || { echo "❌ web-client (ServiceAccount frontend) cannot GET orders (got $(code web-client GET))"; exit 1; }
[ "$(code web-client POST)" = "403" ] || { echo "❌ web-client can use a method other than GET on orders (got $(code web-client POST), expected 403)"; exit 1; }
[ "$(code batch-client GET)" = "403" ] || { echo "❌ batch-client (ServiceAccount scratch) is not denied (got $(code batch-client GET), expected 403)"; exit 1; }

echo "✅ orders accepts GET from the frontend ServiceAccount only"
exit 0
