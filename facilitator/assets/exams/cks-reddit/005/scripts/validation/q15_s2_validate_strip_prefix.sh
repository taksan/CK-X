#!/bin/bash
# Validate by behaviour: the application only knows "/" and "/health.txt", so the prefix /reports
# must be removed before the request reaches it

source "$(dirname "$0")/../lib/ingress-address.sh"
[ -n "$INGRESS_IP" ] && [ -n "$INGRESS_HTTP" ] || { echo "❌ The ingress controller is not reachable"; exit 1; }

get() { curl -s -m 5 -w '\n%{http_code}' --resolve "lab.example.com:$INGRESS_HTTP:$INGRESS_IP" "http://lab.example.com:$INGRESS_HTTP$1" 2>/dev/null; }

for i in $(seq 1 15); do
  R=$(get /reports/health.txt); [ "$(echo "$R" | tail -1)" = "200" ] && break
  sleep 3
done

CODE=$(echo "$R" | tail -1); BODY=$(echo "$R" | sed '$d' | tr -d '[:space:]')
if [ "$CODE" != "200" ] || [ "$BODY" != "ok" ]; then
  echo "❌ GET /reports/health.txt returned HTTP ${CODE:-none} with body '${BODY:0:40}', expected 200 and 'ok' (is the prefix /reports still sent to the application?)"
  exit 1
fi

R=$(get /reports/); CODE=$(echo "$R" | tail -1); BODY=$(echo "$R" | sed '$d' | tr -d '[:space:]')
if [ "$CODE" != "200" ] || [ "$BODY" != "reports-home" ]; then
  echo "❌ GET /reports/ returned HTTP ${CODE:-none} with body '${BODY:0:40}', expected the home page of the application"
  exit 1
fi

echo "✅ The prefix /reports is stripped: /reports/health.txt and /reports/ reach the application"
exit 0
