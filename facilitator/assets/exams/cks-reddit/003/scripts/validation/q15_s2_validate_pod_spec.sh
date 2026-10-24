#!/bin/bash
# Validate Pod token-demo uses api-client and mounts a projected token volume (path token.jwt,
# 600 seconds, audience of the API server) at /var/run/secrets/tokens

NS="${Q15_NAMESPACE:-projected-tokens}"
AUDIENCE="https://kubernetes.default.svc.cluster.local"

JSON=$(kubectl get pod token-demo -n "$NS" -o json 2>/dev/null)
if [ -z "$JSON" ]; then
  echo "❌ Pod 'token-demo' not found in namespace '$NS'"
  exit 1
fi

if [ "$(echo "$JSON" | jq -r '.spec.serviceAccountName')" != "api-client" ]; then
  echo "❌ Pod 'token-demo' does not use the ServiceAccount 'api-client'"
  exit 1
fi

if ! echo "$JSON" | jq -e --arg a "$AUDIENCE" '
    [.spec.volumes[]? | select(.projected != null) | .name as $vol
     | .projected.sources[]? | select(.serviceAccountToken != null)
     | select(.serviceAccountToken.path == "token.jwt" and .serviceAccountToken.expirationSeconds == 600
              and .serviceAccountToken.audience == $a) | $vol] as $vols
    | [.spec.containers[].volumeMounts[]? | select(.mountPath == "/var/run/secrets/tokens" and (.name as $n | $vols | index($n) != null))] | length > 0' >/dev/null; then
  echo "❌ The Pod must mount a projected serviceAccountToken volume (path token.jwt, expirationSeconds 600, audience $AUDIENCE) at /var/run/secrets/tokens"
  exit 1
fi

echo "✅ Pod 'token-demo' uses 'api-client' and mounts the projected token as requested"
exit 0
