#!/bin/bash
# Validate ca.crt holds the decoded CA certificate of the secret platform-certs

FILE="${Q9_FILE:-/tmp/exam/cks-004-q9/ca.crt}"

EXPECTED=$(kubectl get secret platform-certs -n dev -o jsonpath='{.data.ca\.crt}' 2>/dev/null | base64 -d)
[ -n "$EXPECTED" ] || { echo "❌ Secret 'platform-certs' (key ca.crt) not found in namespace 'dev'"; exit 1; }
[ -f "$FILE" ] || { echo "❌ $FILE does not exist"; exit 1; }

if ! openssl x509 -in "$FILE" -noout >/dev/null 2>&1; then
  echo "❌ $FILE is not a valid PEM certificate (is it still base64 encoded?)"
  exit 1
fi

if [ "$(openssl x509 -in "$FILE" -noout -fingerprint -sha256)" != "$(echo "$EXPECTED" | openssl x509 -noout -fingerprint -sha256)" ]; then
  echo "❌ $FILE is not the certificate of the secret platform-certs"
  exit 1
fi

echo "✅ $FILE holds the CA certificate of the secret platform-certs"
exit 0
