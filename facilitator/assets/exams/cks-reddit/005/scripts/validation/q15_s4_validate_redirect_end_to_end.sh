#!/bin/bash
# Validate by behaviour: following the redirect of a legacy URL ends on the application

source "$(dirname "$0")/../lib/ingress-address.sh"
[ -n "$INGRESS_IP" ] && [ -n "$INGRESS_HTTP" ] || { echo "❌ The ingress controller is not reachable"; exit 1; }

for i in $(seq 1 15); do
  R=$(curl -s -m 8 -L --max-redirs 3 -w '\n%{http_code}' --resolve "lab.example.com:$INGRESS_HTTP:$INGRESS_IP" "http://lab.example.com:$INGRESS_HTTP/legacy/health.txt" 2>/dev/null)
  [ "$(echo "$R" | tail -1)" = "200" ] && break
  sleep 3
done
CODE=$(echo "$R" | tail -1); BODY=$(echo "$R" | sed '$d' | tr -d '[:space:]')
if [ "$CODE" != "200" ] || [ "$BODY" != "ok" ]; then
  echo "❌ Following the redirect of /legacy/health.txt ends with HTTP ${CODE:-none} and body '${BODY:0:40}', expected 200 and 'ok'"
  exit 1
fi

echo "✅ /legacy/health.txt leads to the application ('ok')"
exit 0
