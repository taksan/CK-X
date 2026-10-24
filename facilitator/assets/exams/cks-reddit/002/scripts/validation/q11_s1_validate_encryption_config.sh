#!/bin/bash
# Validate the EncryptionConfiguration used by the API server (wherever the file is):
# it targets secrets and the FIRST provider is aescbc, with identity as a fallback.
# (Writes always use the first provider: identity first would store Secrets in plain text.)

NODE="${Q11_NODE:-k8s-api-server}"

CMD=$(kubectl get pods -n kube-system -l component=kube-apiserver -o jsonpath='{.items[0].spec.containers[0].command}' 2>/dev/null || true)
CONFIG=$(echo "$CMD" | grep -o -- '--encryption-provider-config=[^",]*' | head -1 | cut -d= -f2)
if [ -z "$CONFIG" ]; then
  echo "❌ kube-apiserver has no --encryption-provider-config"
  exit 1
fi

CONTENT=$(ssh -o StrictHostKeyChecking=no "$NODE" "cat '$CONFIG'" 2>/dev/null | grep -v '^[[:space:]]*#')
if [ -z "$CONTENT" ]; then
  echo "❌ Encryption configuration '$CONFIG' not found or empty on $NODE"
  exit 1
fi

if ! echo "$CONTENT" | grep -q -- 'kind: EncryptionConfiguration'; then
  echo "❌ $CONFIG is not an EncryptionConfiguration"
  exit 1
fi

if ! echo "$CONTENT" | grep -Eq -- '(^|[^[:alnum:]_])secrets([^[:alnum:]_]|$)'; then
  echo "❌ The encryption configuration does not target secrets"
  exit 1
fi

# providers in order of appearance after the "providers:" line
PROVIDERS=$(echo "$CONTENT" | awk '/providers:/{p=1; next} p && match($0, /^[[:space:]]*-[[:space:]]*(aescbc|aesgcm|secretbox|kms|identity)/) {
  s=$0; sub(/^[[:space:]]*-[[:space:]]*/, "", s); sub(/[^a-z].*$/, "", s); print s }')
FIRST=$(echo "$PROVIDERS" | head -1)

if [ "$FIRST" != "aescbc" ]; then
  echo "❌ The first provider is '${FIRST:-none}', it must be aescbc (the first provider is the one used to write: secrets would not be encrypted)"
  exit 1
fi

if ! echo "$PROVIDERS" | grep -q '^identity$'; then
  echo "❌ The identity provider is missing (it is needed as a fallback to read old, unencrypted data)"
  exit 1
fi

echo "✅ $CONFIG encrypts secrets with aescbc first and keeps identity as a fallback"
exit 0
