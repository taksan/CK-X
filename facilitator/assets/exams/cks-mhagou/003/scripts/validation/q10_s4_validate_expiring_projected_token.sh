#!/bin/bash
# Validate the projected serviceAccountToken source: expirationSeconds 3600 and a valid token for
# token-bot in the same directory (/var/run/secrets/custom-tokens)

source "$(dirname "$0")/../lib/token.sh"

SRC=$(projected_sources serviceAccountToken)
[ -n "$SRC" ] && [ "$SRC" != "[]" ] \
  || { echo "❌ No projected volume of token-pod mounted at $TOKEN_DIR has a serviceAccountToken source"; exit 1; }

EXP=$(echo "$SRC" | jq -r '.[0].expirationSeconds // 3607')
[ "$EXP" = "3600" ] || { echo "❌ The serviceAccountToken source has expirationSeconds $EXP, expected 3600"; exit 1; }

FILE=$(echo "$SRC" | jq -r '.[0].path')
GOT=$(read_in_pod "$TOKEN_DIR/$FILE" | tr -d '\n')
[ -n "$GOT" ] || { echo "❌ The file $TOKEN_DIR/$FILE cannot be read in the Pod"; exit 1; }

C=$(jwt_claims "$GOT")
LIFE=$(echo "$C" | jq -r '(.exp - .iat) // empty' 2>/dev/null)
[ "$LIFE" = "3600" ] || { echo "❌ The token in $TOKEN_DIR/$FILE has a lifetime of ${LIFE:-?} seconds, expected 3600"; exit 1; }

U=$(token_user "$GOT")
[ "$U" = "system:serviceaccount:token-lab:token-bot" ] || { echo "❌ The token in $TOKEN_DIR/$FILE is not accepted as the ServiceAccount token-bot (authenticated as '${U:-nobody}')"; exit 1; }

echo "✅ $TOKEN_DIR/$FILE is a projected token of token-bot that expires after 3600 seconds"
exit 0
