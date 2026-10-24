#!/bin/bash
# Validate by behaviour: https://bingo.com answers with the page of the Pod and serves the
# certificate that was provided (CN=bingo.com)

source "$(dirname "$0")/../lib/ingress-address.sh"
DIR="${Q10_DIR:-/tmp/exam/cks-003-q10}"
if [ -z "$INGRESS_IP" ] || [ -z "$INGRESS_HTTPS" ]; then
  echo "❌ The ingress controller (namespace ingress-nginx) is not reachable"
  exit 1
fi

for i in $(seq 1 15); do
  BODY=$(curl -sk -m 5 --resolve "bingo.com:$INGRESS_HTTPS:$INGRESS_IP" "https://bingo.com:$INGRESS_HTTPS/" 2>/dev/null)
  echo "$BODY" | grep -qi "nginx" && break
  sleep 3
done

if ! echo "$BODY" | grep -qi "nginx"; then
  echo "❌ https://bingo.com does not return the page of the nginx Pod"
  exit 1
fi

SERVED=$(echo | openssl s_client -connect "$INGRESS_IP:$INGRESS_HTTPS" -servername bingo.com 2>/dev/null | openssl x509 -noout -fingerprint -sha256 2>/dev/null)
EXPECTED=$(openssl x509 -in "$DIR/bingo.crt" -noout -fingerprint -sha256 2>/dev/null)
if [ -z "$SERVED" ] || [ "$SERVED" != "$EXPECTED" ]; then
  echo "❌ The controller does not serve the provided certificate for bingo.com (still its default certificate?)"
  exit 1
fi

echo "✅ https://bingo.com returns the Pod's page with the provided certificate"
exit 0
