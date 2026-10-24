#!/bin/bash
# Validate by behaviour: the Pods of Deployment stuff cannot ping the Pod behind Service backend,
# while TCP to it and the ping from other Pods still work (the existing default-allow stays)

NS="team-dev"

kubectl get ciliumnetworkpolicy default-allow -n "$NS" >/dev/null 2>&1 || { echo "❌ The existing CiliumNetworkPolicy 'default-allow' was deleted"; exit 1; }

IP=$(kubectl get pod backend-0 -n "$NS" -o jsonpath='{.status.podIP}' 2>/dev/null)
[ -n "$IP" ] || { echo "❌ Pod backend-0 has no IP"; exit 1; }

ping_ok() { kubectl exec -n "$NS" "$1" -- ping -c 1 -W 2 "$IP" >/dev/null 2>&1; }
tcp_ok()  { kubectl exec -n "$NS" "$1" -- wget -q -T 3 -O /dev/null "http://$IP" >/dev/null 2>&1; }

STUFF=$(kubectl get pods -n "$NS" -l app=stuff -o jsonpath='{.items[*].metadata.name}')

# the policy takes a few seconds to be enforced: wait until the first stuff Pod is blocked (or give up)
for i in $(seq 1 10); do
  ping_ok "$(echo $STUFF | awk '{print $1}')" || break
  sleep 3
done

for p in $STUFF; do
  if ping_ok "$p"; then
    echo "❌ $p can still ping the Pod behind the Service backend"
    exit 1
  fi
  if ! tcp_ok "$p"; then
    echo "❌ $p can no longer open TCP connections to backend: only ICMP must be denied"
    exit 1
  fi
done

if ! ping_ok database-0; then
  echo "❌ database-0 cannot ping backend: the policy must only affect the Pods of Deployment stuff"
  exit 1
fi

echo "✅ stuff Pods cannot ping backend; TCP works and other Pods can still ping it"
exit 0
