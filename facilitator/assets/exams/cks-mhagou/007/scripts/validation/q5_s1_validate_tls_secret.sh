#!/bin/bash
# Item: the TLS Secret secret-tls is made from the provided certificate and key

DIR="${Q5_DIR:-/tmp/exam/mhagou-007-q5}"
J=$(kubectl get secret secret-tls -n rocket -o json 2>/dev/null)
[ -n "$J" ] || { echo "❌ Secret 'secret-tls' not found in namespace 'rocket'"; exit 1; }
[ "$(echo "$J" | jq -r '.type')" = "kubernetes.io/tls" ] || { echo "❌ Secret secret-tls is not of type kubernetes.io/tls"; exit 1; }

GOT=$(echo "$J" | jq -r '.data["tls.crt"]' | base64 -d 2>/dev/null | openssl x509 -noout -fingerprint -sha256 2>/dev/null)
WANT=$(openssl x509 -in "$DIR/rocket.crt" -noout -fingerprint -sha256 2>/dev/null)
[ -n "$WANT" ] && [ "$GOT" = "$WANT" ] || { echo "❌ The certificate in secret-tls is not $DIR/rocket.crt"; exit 1; }
KEYSUM=$(echo "$J" | jq -r '.data["tls.key"]' | base64 -d 2>/dev/null | openssl pkey -pubout 2>/dev/null | sha256sum)
WANTKEY=$(openssl pkey -in "$DIR/rocket.key" -pubout 2>/dev/null | sha256sum)
[ "$KEYSUM" = "$WANTKEY" ] || { echo "❌ The key in secret-tls is not $DIR/rocket.key"; exit 1; }

echo "✅ secret-tls is made from the provided certificate and key"
exit 0
