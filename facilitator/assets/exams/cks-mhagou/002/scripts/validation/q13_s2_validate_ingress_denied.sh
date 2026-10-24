#!/bin/bash
# By behaviour: nothing reaches the Pod server of lockdown (neither a Pod of the same namespace nor
# a Pod of another namespace)

IP=$(kubectl get pod server -n lockdown -o jsonpath='{.status.podIP}' 2>/dev/null)
[ -n "$IP" ] || { echo "❌ Pod 'server' of the namespace lockdown has no IP"; exit 1; }
get() { kubectl exec -n "$1" "$2" -- wget -q -T 3 -O /dev/null "http://$IP:80" >/dev/null 2>&1; }

# the policy takes a few seconds to be enforced
for i in $(seq 1 10); do
  get lockdown-ext outsider || break
  sleep 3
done

get lockdown-ext outsider && { echo "❌ A Pod of another namespace still reaches the Pod server"; exit 1; }
# the Pod client must be blocked on its way out too, but here only the ingress side is checked:
# some policy must be present (its name is checked by the object check only); a connection that
# fails for another reason must not count
kubectl get networkpolicy -n lockdown --no-headers 2>/dev/null | grep -q . || { echo "❌ No NetworkPolicy found in namespace 'lockdown'"; exit 1; }
get lockdown client && { echo "❌ A Pod of the same namespace (client) still reaches the Pod server"; exit 1; }

echo "✅ No Pod can reach server: all ingress is denied"
exit 0
