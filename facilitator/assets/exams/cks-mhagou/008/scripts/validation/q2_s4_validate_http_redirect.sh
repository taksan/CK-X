#!/bin/bash
# Item: plain HTTP requests for secure-app.company.com are redirected to HTTPS

source "$(dirname "$0")/../lib/ingress-address.sh"
if [ -z "$INGRESS_IP" ] || [ -z "$INGRESS_HTTP" ]; then
  echo "❌ The ingress controller is not reachable"
  exit 1
fi

for i in $(seq 1 15); do
  H=$(curl -s -m 5 -o /dev/null -D - --resolve "secure-app.company.com:$INGRESS_HTTP:$INGRESS_IP" "http://secure-app.company.com:$INGRESS_HTTP/" 2>/dev/null)
  CODE=$(echo "$H" | head -1 | awk '{print $2}')
  case "$CODE" in 301|302|307|308) break ;; esac
  sleep 3
done
LOC=$(echo "$H" | grep -i '^location:' | tr -d '\r' | awk '{print $2}')

case "$CODE" in
  301|302|307|308) ;;
  *) echo "❌ http://secure-app.company.com/ is not redirected (HTTP status: ${CODE:-none}); the Ingress needs a redirect to HTTPS"; exit 1 ;;
esac

case "$LOC" in
  https://secure-app.company.com*) ;;
  *) echo "❌ The redirect points to '$LOC', expected https://secure-app.company.com/"; exit 1 ;;
esac

echo "✅ http://secure-app.company.com/ is redirected to $LOC ($CODE)"
exit 0
