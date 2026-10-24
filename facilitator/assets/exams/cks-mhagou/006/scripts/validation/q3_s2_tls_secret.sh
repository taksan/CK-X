#!/bin/bash
# Secret test-secret in world: TLS Secret with the supplied certificate and its matching key

DIR="${Q3_DIR:-/tmp/exam/mhagou-006-q3}"
J=$(kubectl get secret test-secret -n world -o json 2>/dev/null)
[ -n "$J" ] || { echo "❌ Secret 'test-secret' not found in namespace 'world'"; exit 1; }
[ "$(echo "$J" | jq -r '.type')" = "kubernetes.io/tls" ] || { echo "❌ Secret 'test-secret' is not of type kubernetes.io/tls"; exit 1; }

CERT=$(echo "$J" | jq -r '.data["tls.crt"]' | base64 -d 2>/dev/null | openssl x509 -noout -fingerprint -sha256 2>/dev/null)
WANT=$(openssl x509 -in "$DIR/cert.crt" -noout -fingerprint -sha256 2>/dev/null)
[ -n "$CERT" ] && [ "$CERT" = "$WANT" ] || { echo "❌ The certificate of 'test-secret' is not the supplied $DIR/cert.crt"; exit 1; }

PUB1=$(echo "$J" | jq -r '.data["tls.key"]' | base64 -d 2>/dev/null | openssl pkey -pubout 2>/dev/null | sha256sum)
PUB2=$(openssl pkey -in "$DIR/cert.key" -pubout 2>/dev/null | sha256sum)
[ "$PUB1" = "$PUB2" ] || { echo "❌ The private key of 'test-secret' is not the supplied $DIR/cert.key"; exit 1; }

echo "✅ Secret 'test-secret' uses the supplied certificate and key"
exit 0
