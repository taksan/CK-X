#!/bin/bash
# Validate by behaviour that egress is denied: the client cannot reach the server Pod, nor
# the Kubernetes API Service

NS="egress-lab"

SERVER=$(kubectl get pod server -n "$NS" -o jsonpath='{.status.podIP}' 2>/dev/null)
[ -n "$SERVER" ] || { echo "❌ Pod 'server' has no IP"; exit 1; }
API=$(kubectl get svc kubernetes -n default -o jsonpath='{.spec.clusterIP}')

open() { kubectl exec -n "$NS" client -- wget -q -T 3 -O /dev/null "$1" >/dev/null 2>&1; }

# the policy takes a few seconds to be enforced
for i in $(seq 1 10); do open "http://$SERVER" || break; sleep 3; done

if open "http://$SERVER"; then
  echo "❌ The client can still open connections to the server Pod: egress is not denied"
  exit 1
fi
# the API Service answers (even with an error such as 401/403 or a TLS message) unless the connection is blocked
OUT=$(kubectl exec -n "$NS" client -- wget -T 3 --no-check-certificate -O /dev/null "https://$API" 2>&1)
if ! echo "$OUT" | grep -qi "timed out"; then
  echo "❌ The client can still reach the Kubernetes API Service: egress is not denied"
  exit 1
fi

echo "✅ The client Pod cannot open connections to the server Pod or to the Kubernetes API"
exit 0
