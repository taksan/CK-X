#!/bin/bash
# Validate by behaviour who can reach products-service on port 80:
#   a Pod of dev-team                        -> allowed
#   a Pod labelled environment=testing (qa)  -> allowed
#   any other Pod from another namespace     -> denied

NS="dev-team"

IP=$(kubectl get pod products-service -n "$NS" -o jsonpath='{.status.podIP}' 2>/dev/null)
if [ -z "$IP" ]; then
  echo "❌ Pod products-service has no IP (is it running?)"
  exit 1
fi

reach() { # namespace pod -> 0 when it can open an HTTP connection
  kubectl exec -n "$1" "$2" -- wget -q -T 3 -O /dev/null "http://$IP:80" >/dev/null 2>&1
}

# the policy takes a few seconds to be enforced: wait until the visitor is blocked (or give up)
for i in $(seq 1 10); do
  reach qa-team visitor || break
  sleep 3
done

FAIL=0
reach dev-team orders-client || { echo "❌ A Pod of the same namespace (dev-team/orders-client) cannot reach products-service"; FAIL=1; }
reach qa-team tester         || { echo "❌ A Pod labelled environment=testing (qa-team/tester) cannot reach products-service"; FAIL=1; }
reach qa-team visitor        && { echo "❌ A Pod from another namespace without environment=testing (qa-team/visitor) can still reach products-service"; FAIL=1; }

[ "$FAIL" -eq 0 ] || exit 1
echo "✅ Same-namespace Pods and environment=testing Pods can reach products-service; other Pods cannot"
exit 0
