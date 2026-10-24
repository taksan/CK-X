#!/bin/bash
# Validate the token the Pod really sees: file present, subject api-client, the requested
# audience and a lifetime of about 600 seconds (the Pod must be running)

NS="${Q15_NAMESPACE:-projected-tokens}"
AUDIENCE="https://kubernetes.default.svc.cluster.local"

PHASE=$(kubectl get pod token-demo -n "$NS" -o jsonpath='{.status.phase}' 2>/dev/null)
if [ "$PHASE" != "Running" ]; then
  echo "❌ Pod 'token-demo' is not running (phase: ${PHASE:-none})"
  exit 1
fi

TOKEN=$(kubectl exec token-demo -n "$NS" -- cat /var/run/secrets/tokens/token.jwt 2>/dev/null)
if [ -z "$TOKEN" ]; then
  echo "❌ /var/run/secrets/tokens/token.jwt does not exist in the Pod"
  exit 1
fi

# JWT payload: base64url, without padding
PAYLOAD=$(echo "$TOKEN" | cut -d. -f2 | tr '_-' '/+')
case $(( ${#PAYLOAD} % 4 )) in 2) PAYLOAD="$PAYLOAD==";; 3) PAYLOAD="$PAYLOAD=";; esac
CLAIMS=$(echo "$PAYLOAD" | base64 -d 2>/dev/null)

if ! echo "$CLAIMS" | jq -e --arg sub "system:serviceaccount:$NS:api-client" --arg aud "$AUDIENCE" '
    .sub == $sub and ((.aud | if type == "array" then . else [.] end) | index($aud) != null)
    and ((.exp - .iat) >= 590 and (.exp - .iat) <= 610)' >/dev/null 2>&1; then
  echo "❌ The token is not a 600 second token of api-client for the audience $AUDIENCE"
  exit 1
fi

echo "✅ The token belongs to api-client, has the requested audience and lasts 600 seconds"
exit 0
