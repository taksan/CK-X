#!/bin/bash
# Validate the token Secret is projected into /var/run/secrets/custom-tokens: the file of the Pod holds
# the Secret's token and the API server authenticates it as the ServiceAccount token-bot

source "$(dirname "$0")/../lib/token.sh"

SRC=$(projected_sources secret)
[ -n "$SRC" ] && [ "$SRC" != "[]" ] \
  || { echo "❌ No projected volume of token-pod mounted at $TOKEN_DIR has a secret source"; exit 1; }

# the Secret must be a ServiceAccount token Secret of token-bot
NAME=$(echo "$SRC" | jq -r '.[0].name')
T=$(kubectl get secret "$NAME" -n "$TOKEN_NS" -o json 2>/dev/null)
[ "$(echo "$T" | jq -r '.type')" = "kubernetes.io/service-account-token" ] \
  || { echo "❌ The projected Secret '$NAME' is not a Secret of type kubernetes.io/service-account-token"; exit 1; }
EXPECTED=$(echo "$T" | jq -r '.data.token // empty' | base64 -d 2>/dev/null)
[ -n "$EXPECTED" ] || { echo "❌ The projected Secret '$NAME' holds no token"; exit 1; }

# file name of the token key inside the volume
FILE=$(echo "$SRC" | jq -r '[.[0].items[]? | select(.key == "token") | .path][0] // "token"')
GOT=$(read_in_pod "$TOKEN_DIR/$FILE" | tr -d '\n')
[ -n "$GOT" ] || { echo "❌ The file $TOKEN_DIR/$FILE cannot be read in the Pod"; exit 1; }
[ "$GOT" = "$EXPECTED" ] || { echo "❌ The file $TOKEN_DIR/$FILE does not hold the token of the Secret '$NAME'"; exit 1; }

U=$(token_user "$GOT")
[ "$U" = "system:serviceaccount:token-lab:token-bot" ] || { echo "❌ The token in $TOKEN_DIR/$FILE is not accepted as the ServiceAccount token-bot (authenticated as '${U:-nobody}')"; exit 1; }

echo "✅ The Secret token is projected at $TOKEN_DIR/$FILE and authenticates as token-bot"
exit 0
