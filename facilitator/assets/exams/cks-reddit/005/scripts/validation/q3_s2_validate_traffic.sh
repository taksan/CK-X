#!/bin/bash
# Validate by behaviour: in staging the Pod web accepts port 80 from the namespace only

IP=$(kubectl get pod web -n staging -o jsonpath='{.status.podIP}' 2>/dev/null)
[ -n "$IP" ] || { echo "❌ Pod web has no IP"; exit 1; }
get() { kubectl exec -n "$1" "$2" -- wget -q -T 4 -O /dev/null "http://$IP:$3" >/dev/null 2>&1; }

# the policy needs a few seconds to be enforced
for i in $(seq 1 10); do
  get staging-ext outsider 80 || break
  sleep 3
done

get staging peer 80 || { echo "❌ The Pod peer of the same namespace cannot reach port 80 of web"; exit 1; }
get staging-ext outsider 80 && { echo "❌ A Pod of another namespace reaches port 80 of web"; exit 1; }
get staging peer 8080 && { echo "❌ Port 8080 of web is reachable: only port 80 may be allowed"; exit 1; }
get staging-ext outsider 8080 && { echo "❌ Port 8080 of web is reachable from another namespace"; exit 1; }

echo "✅ web accepts port 80 from its own namespace only"
exit 0
