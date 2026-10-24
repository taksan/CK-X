#!/bin/bash
# Behaviour: https://world.universe.mine/europe through the Traefik controller verifies the supplied
# certificate, returns HTTP 200 and serves the nginx welcome page of the Europe backend (the prefix
# /europe must not reach nginx)

DIR="${Q3_DIR:-/tmp/exam/mhagou-006-q3}"
source "$(dirname "$0")/../lib/ingress-address.sh"
[ -n "$INGRESS_IP" ] && [ -n "$INGRESS_HTTPS" ] || { echo "❌ The ingress controller is not reachable"; exit 1; }

for i in $(seq 1 15); do
  OUT=$(curl -s -m 8 --cacert "$DIR/cert.crt" --resolve "world.universe.mine:$INGRESS_HTTPS:$INGRESS_IP" -w '\n%{http_code}|%{ssl_verify_result}' "https://world.universe.mine:$INGRESS_HTTPS/europe" 2>/dev/null)
  CODE=$(echo "$OUT" | tail -1 | cut -d'|' -f1)
  [ "$CODE" = "200" ] && break
  sleep 3
done

VERIFY=$(echo "$OUT" | tail -1 | cut -d'|' -f2)
BODY=$(echo "$OUT" | sed '$d')
[ "$CODE" = "200" ] || { echo "❌ GET https://world.universe.mine/europe returned HTTP ${CODE:-none}, expected 200 (does the prefix /europe reach nginx? is the TLS secret used?)"; exit 1; }
[ "$VERIFY" = "0" ] || { echo "❌ The certificate served for world.universe.mine is not the supplied one (verification result $VERIFY)"; exit 1; }
echo "$BODY" | grep -q "Welcome to nginx" || { echo "❌ The response is not the nginx welcome page of the backend"; exit 1; }

echo "✅ https://world.universe.mine/europe verifies the supplied certificate and serves the nginx welcome page"
exit 0
