#!/bin/bash
# Item: by behaviour, nothing reaches the Pod server (neither from its namespace nor from another one)

SERVER_IP=$(kubectl get pod server -n testing -o jsonpath='{.status.podIP}' 2>/dev/null)
[ -n "$SERVER_IP" ] || { echo "❌ Pod server has no IP"; exit 1; }
reach() { kubectl exec -n "$1" "$2" -- wget -q -T 3 -O /dev/null "http://$3:80" >/dev/null 2>&1; }

# the policy needs a few seconds to be enforced
for i in $(seq 1 12); do
  reach testing-ext outsider "$SERVER_IP" || break
  sleep 3
done

reach testing-ext outsider "$SERVER_IP" && { echo "❌ A Pod of another namespace (testing-ext/outsider) still reaches testing/server"; exit 1; }
reach testing client "$SERVER_IP" && { echo "❌ A Pod of the same namespace (testing/client) still reaches testing/server"; exit 1; }

echo "✅ Ingress to the Pods of testing is blocked"
exit 0
