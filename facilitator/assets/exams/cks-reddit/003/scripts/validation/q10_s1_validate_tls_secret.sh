#!/bin/bash
# Validate the TLS Secret bingo-tls was created from the provided certificate and key

NS="web-tls"
DIR="${Q10_DIR:-/tmp/exam/cks-003-q10}"

JSON=$(kubectl get secret bingo-tls -n "$NS" -o json 2>/dev/null)
if [ -z "$JSON" ]; then
  echo "❌ Secret 'bingo-tls' not found in namespace '$NS'"
  exit 1
fi

if [ "$(echo "$JSON" | jq -r '.type')" != "kubernetes.io/tls" ]; then
  echo "❌ Secret 'bingo-tls' is not of type kubernetes.io/tls"
  exit 1
fi

if [ "$(echo "$JSON" | jq -r '.data["tls.crt"]' | base64 -d)" != "$(cat "$DIR/bingo.crt")" ] \
   || [ "$(echo "$JSON" | jq -r '.data["tls.key"]' | base64 -d)" != "$(cat "$DIR/bingo.key")" ]; then
  echo "❌ Secret 'bingo-tls' does not contain the provided bingo.crt and bingo.key"
  exit 1
fi

echo "✅ Secret 'bingo-tls' is a TLS Secret made from bingo.crt and bingo.key"
exit 0
