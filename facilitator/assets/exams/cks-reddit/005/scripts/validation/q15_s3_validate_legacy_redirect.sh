#!/bin/bash
# Validate by behaviour: /legacy/<file> is redirected permanently to /reports/<file>

source "$(dirname "$0")/../lib/ingress-address.sh"
[ -n "$INGRESS_IP" ] && [ -n "$INGRESS_HTTP" ] || { echo "❌ The ingress controller is not reachable"; exit 1; }

for i in $(seq 1 15); do
  H=$(curl -s -m 5 -o /dev/null -D - --resolve "lab.example.com:$INGRESS_HTTP:$INGRESS_IP" "http://lab.example.com:$INGRESS_HTTP/legacy/health.txt" 2>/dev/null)
  CODE=$(echo "$H" | head -1 | awk '{print $2}')
  case "$CODE" in 301|302|307|308) break ;; esac
  sleep 3
done
LOC=$(echo "$H" | grep -i '^location:' | tr -d '\r' | awk '{print $2}')

case "$CODE" in
  301|308) ;;
  302|307) echo "❌ /legacy/health.txt is redirected with the temporary status $CODE: the redirect must be permanent (301 or 308)"; exit 1 ;;
  *) echo "❌ /legacy/health.txt is not redirected (HTTP status: ${CODE:-none})"; exit 1 ;;
esac

PATH_ONLY=$(echo "$LOC" | sed -E 's#^https?://[^/]+##')
[ "$PATH_ONLY" = "/reports/health.txt" ] || { echo "❌ The redirect points to '$LOC', expected /reports/health.txt (the path after /legacy/ must be kept)"; exit 1; }
case "$LOC" in http*://*) echo "$LOC" | grep -q '^https\?://lab.example.com' || { echo "❌ The redirect leaves the host lab.example.com ($LOC)"; exit 1; } ;; esac

echo "✅ /legacy/health.txt is redirected permanently ($CODE) to $LOC"
exit 0
