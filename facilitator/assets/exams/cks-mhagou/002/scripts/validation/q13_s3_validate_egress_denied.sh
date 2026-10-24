#!/bin/bash
# By behaviour: the Pod client of lockdown cannot open any connection: not to server, not to the
# cluster DNS, not to the API service. Credited only when some policy exists in the namespace (its name is checked by the object
# check only; a connection that fails for another reason must not count).

kubectl get networkpolicy -n lockdown --no-headers 2>/dev/null | grep -q . || { echo "❌ No NetworkPolicy found in namespace 'lockdown'"; exit 1; }

IP=$(kubectl get pod server -n lockdown -o jsonpath='{.status.podIP}' 2>/dev/null)
API=$(kubectl get svc kubernetes -n default -o jsonpath='{.spec.clusterIP}' 2>/dev/null)
[ -n "$IP" ] && [ -n "$API" ] || { echo "❌ Pod server has no IP or the API service was not found"; exit 1; }

dns() { kubectl exec -n lockdown client -- nslookup -timeout=3 kubernetes.default.svc.cluster.local >/dev/null 2>&1; }
http() { kubectl exec -n lockdown client -- wget -q -T 3 -O /dev/null "$1" >/dev/null 2>&1; }

for i in $(seq 1 10); do
  http "http://$IP:80" || break
  sleep 3
done

http "http://$IP:80" && { echo "❌ The Pod client still reaches the Pod server (egress is not denied)"; exit 1; }
dns && { echo "❌ The Pod client can still resolve names: DNS traffic (egress) must be denied too"; exit 1; }
http "https://$API:443" && { echo "❌ The Pod client still reaches the API service"; exit 1; }

echo "✅ The Pod client cannot open any connection: all egress is denied"
exit 0
