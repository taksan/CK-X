#!/bin/bash
# Item: plain HTTP requests for rocket-server.local are redirected to HTTPS

source "$(dirname "$0")/../lib/ingress-address.sh"
[ -n "$INGRESS_IP" ] && [ -n "$INGRESS_HTTP" ] || { echo "❌ The ingress controller is not reachable"; exit 1; }

for i in $(seq 1 15); do
  H=$(curl -s -m 5 -o /dev/null -D - --resolve "rocket-server.local:$INGRESS_HTTP:$INGRESS_IP" "http://rocket-server.local:$INGRESS_HTTP/" 2>/dev/null)
  CODE=$(echo "$H" | head -1 | awk '{print $2}')
  case "$CODE" in 301|302|307|308) break ;; esac
  sleep 3
done
LOC=$(echo "$H" | grep -i '^location:' | tr -d '\r' | awk '{print $2}')
case "$CODE" in
  301|302|307|308) ;;
  *) echo "❌ http://rocket-server.local is not redirected (HTTP status: ${CODE:-none})"; exit 1 ;;
esac
[[ "$LOC" == https://rocket-server.local* ]] || { echo "❌ The redirect does not point to https://rocket-server.local (Location: $LOC)"; exit 1; }

echo "✅ http://rocket-server.local is redirected to $LOC"
exit 0
