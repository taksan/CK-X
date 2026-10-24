#!/bin/bash
# Behaviour: the ingress controller serves the certificate of the Secret for the host over HTTPS
# and the application answers

source "$(dirname "$0")/../lib/q2-lib.sh"
source "$(dirname "$0")/../lib/ingress-address.sh"
find_tls_host || exit 1
[ -n "$INGRESS_IP" ] && [ -n "$INGRESS_HTTPS" ] || { echo "❌ The ingress controller is not reachable"; exit 1; }

WANT=$(openssl x509 -in "$TLS_CERT" -noout -fingerprint -sha256 2>/dev/null)
GOT=""
CODE=""
# the controller needs a few seconds to pick up a new Ingress
for i in $(seq 1 15); do
  GOT=$(echo | openssl s_client -connect "$INGRESS_IP:$INGRESS_HTTPS" -servername "$TLS_HOST" 2>/dev/null | openssl x509 -noout -fingerprint -sha256 2>/dev/null)
  [ "$GOT" = "$WANT" ] && break
  sleep 3
done
if [ "$GOT" != "$WANT" ]; then
  echo "❌ The ingress controller does not serve the certificate of the Secret $TLS_SECRET for $TLS_HOST (it serves '${GOT:-nothing}')"
  exit 1
fi

CODE=$(curl -sk -m 8 -o /dev/null -w '%{http_code}' --resolve "$TLS_HOST:$INGRESS_HTTPS:$INGRESS_IP" "https://$TLS_HOST:$INGRESS_HTTPS/" 2>/dev/null)
[ "$CODE" = "200" ] || { echo "❌ https://$TLS_HOST/ answers HTTP ${CODE:-none}, expected 200 from the application"; exit 1; }

echo "✅ https://$TLS_HOST/ is served with the certificate of the Secret $TLS_SECRET and reaches the application"
exit 0
