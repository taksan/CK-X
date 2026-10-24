#!/bin/bash
# Item: https://rocket-server.local is served by the application (through the Traefik address)

source "$(dirname "$0")/../lib/ingress-address.sh"
[ -n "$INGRESS_IP" ] && [ -n "$INGRESS_HTTPS" ] || { echo "❌ The ingress controller is not reachable"; exit 1; }

for i in $(seq 1 15); do
  BODY=$(curl -sk -m 5 --resolve "rocket-server.local:$INGRESS_HTTPS:$INGRESS_IP" "https://rocket-server.local:$INGRESS_HTTPS/" 2>/dev/null)
  echo "$BODY" | grep -q 'MHagou rocket-server' && break
  sleep 3
done
echo "$BODY" | grep -q 'MHagou rocket-server' || { echo "❌ https://rocket-server.local/ does not return the page of rocket-server"; exit 1; }

echo "✅ https://rocket-server.local/ is served by rocket-server"
exit 0
