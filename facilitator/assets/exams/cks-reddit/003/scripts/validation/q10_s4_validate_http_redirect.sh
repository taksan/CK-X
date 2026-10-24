#!/bin/bash
# Validate by behaviour: plain HTTP requests for bingo.com are redirected to HTTPS

source "$(dirname "$0")/../lib/ingress-address.sh"
if [ -z "$INGRESS_IP" ] || [ -z "$INGRESS_HTTP" ]; then
  echo "❌ The ingress controller (namespace ingress-nginx) is not reachable"
  exit 1
fi

# the controller needs a few seconds to pick up a new Ingress
for i in $(seq 1 15); do
  HEADERS=$(curl -s -m 5 -o /dev/null -D - --resolve "bingo.com:$INGRESS_HTTP:$INGRESS_IP" "http://bingo.com:$INGRESS_HTTP/" 2>/dev/null)
  CODE=$(echo "$HEADERS" | head -1 | awk '{print $2}')
  LOCATION=$(echo "$HEADERS" | grep -i '^location:' | tr -d '\r' | awk '{print $2}')
  case "$CODE" in 301|302|307|308) break ;; esac
  sleep 3
done

case "$CODE" in
  301|302|307|308) ;;
  *) echo "❌ http://bingo.com is not redirected (HTTP status: ${CODE:-none})"; exit 1 ;;
esac

if [[ "$LOCATION" != https://bingo.com* ]]; then
  echo "❌ The redirect does not point to https://bingo.com (Location: $LOCATION)"
  exit 1
fi

echo "✅ http://bingo.com is redirected to $LOCATION"
exit 0
