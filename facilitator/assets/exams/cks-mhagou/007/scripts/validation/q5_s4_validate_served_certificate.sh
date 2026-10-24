#!/bin/bash
# Item: the controller serves the provided certificate for rocket-server.local

DIR="${Q5_DIR:-/tmp/exam/mhagou-007-q5}"
source "$(dirname "$0")/../lib/ingress-address.sh"
[ -n "$INGRESS_IP" ] && [ -n "$INGRESS_HTTPS" ] || { echo "❌ The ingress controller is not reachable"; exit 1; }

WANT=$(openssl x509 -in "$DIR/rocket.crt" -noout -fingerprint -sha256 2>/dev/null)
[ -n "$WANT" ] || { echo "❌ $DIR/rocket.crt is missing"; exit 1; }
for i in $(seq 1 15); do
  SERVED=$(echo | openssl s_client -connect "$INGRESS_IP:$INGRESS_HTTPS" -servername rocket-server.local 2>/dev/null | openssl x509 -noout -fingerprint -sha256 2>/dev/null)
  [ "$SERVED" = "$WANT" ] && break
  sleep 3
done
[ "$SERVED" = "$WANT" ] || { echo "❌ The controller does not serve the provided certificate for rocket-server.local (its default certificate is served: does the Ingress reference an existing Secret?)"; exit 1; }

echo "✅ The provided certificate is served for rocket-server.local"
exit 0
