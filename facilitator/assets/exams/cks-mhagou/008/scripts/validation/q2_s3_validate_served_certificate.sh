#!/bin/bash
# Item: the controller serves the certificate of the Secret web-tls for secure-app.company.com

source "$(dirname "$0")/../lib/ingress-address.sh"
if [ -z "$INGRESS_IP" ] || [ -z "$INGRESS_HTTPS" ]; then
  echo "❌ The ingress controller is not reachable"
  exit 1
fi

EXPECTED=$(kubectl get secret web-tls -n secure-web -o jsonpath='{.data.tls\.crt}' 2>/dev/null | base64 -d 2>/dev/null | openssl x509 -noout -fingerprint -sha256 2>/dev/null)
[ -n "$EXPECTED" ] || { echo "❌ Secret web-tls (tls.crt) not found in namespace secure-web: it must not be deleted"; exit 1; }

for i in $(seq 1 15); do
  SERVED=$(echo | openssl s_client -connect "$INGRESS_IP:$INGRESS_HTTPS" -servername secure-app.company.com 2>/dev/null | openssl x509 -noout -fingerprint -sha256 2>/dev/null)
  [ "$SERVED" = "$EXPECTED" ] && break
  sleep 3
done

if [ "$SERVED" != "$EXPECTED" ]; then
  echo "❌ The controller does not serve the certificate of web-tls for secure-app.company.com (the default certificate of the controller is served: is the Secret referenced by the Ingress?)"
  exit 1
fi

echo "✅ The certificate of web-tls is served for secure-app.company.com"
exit 0
