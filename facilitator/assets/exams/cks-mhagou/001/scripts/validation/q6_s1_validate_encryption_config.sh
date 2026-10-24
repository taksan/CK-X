#!/bin/bash
# Item: the API server uses an EncryptionConfiguration for secrets whose first provider is aescbc with a
# valid key (16/24/32 bytes, base64) and identity as a fallback (the file can be anywhere)

source "$(dirname "$0")/../lib/apiserver.sh"

FILE=$(apiserver_flag encryption-provider-config)
[ -n "$FILE" ] || { echo "❌ kube-apiserver has no --encryption-provider-config flag in its manifest"; exit 1; }

CFG=$(ssh -o StrictHostKeyChecking=no "$APISERVER_NODE" "yq -o=json '.' '$FILE'" 2>/dev/null)
[ -n "$CFG" ] || { echo "❌ The encryption configuration '$FILE' does not exist or is not valid YAML on the control plane"; exit 1; }

echo "$CFG" | jq -e '.kind == "EncryptionConfiguration"' >/dev/null || { echo "❌ $FILE is not an EncryptionConfiguration"; exit 1; }
RES=$(echo "$CFG" | jq -c '[.resources[]? | select((.resources // []) | index("secrets") != null)][0] // empty')
[ -n "$RES" ] || { echo "❌ $FILE does not target the resource secrets"; exit 1; }

FIRST=$(echo "$RES" | jq -r '.providers[0] | keys[0] // empty')
[ "$FIRST" = "aescbc" ] || { echo "❌ The first provider is '${FIRST:-none}': it must be aescbc (the first provider is the one used to write)"; exit 1; }

KEY=$(echo "$RES" | jq -r '.providers[0].aescbc.keys[0].secret // empty')
LEN=$(printf '%s' "$KEY" | base64 -d 2>/dev/null | wc -c)
case "$LEN" in
  16|24|32) ;;
  *) echo "❌ The aescbc key is not a base64 string of 16, 24 or 32 bytes (decoded length: $LEN)"; exit 1 ;;
esac

echo "$RES" | jq -e 'any(.providers[]?; has("identity"))' >/dev/null || { echo "❌ The identity provider is missing (it is the fallback to read existing, unencrypted Secrets)"; exit 1; }

echo "✅ $FILE encrypts secrets with aescbc first and keeps identity as the fallback"
exit 0
