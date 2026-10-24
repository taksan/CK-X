#!/bin/bash
# Validate deployment.yaml uses the verified image, pinned by digest

DIR="${Q5_DIR:-/tmp/exam/cks-005-q5}"
F="$DIR/deployment.yaml"
[ -f "$DIR/.state" ] || { echo "❌ Internal state file missing"; exit 1; }
. "$DIR/.state"
[ -f "$F" ] || { echo "❌ $F does not exist"; exit 1; }

J=$(kubectl create --dry-run=client -o json -f "$F" 2>/dev/null)
[ -n "$J" ] || { echo "❌ $F is not a valid manifest"; exit 1; }

IMAGE=$(echo "$J" | jq -r '.spec.template.spec.containers[0].image')
if [ "$IMAGE" != "$REGISTRY/payments@$TRUSTED_DIGEST" ]; then
  echo "❌ The image is '$IMAGE', expected the verified image pinned by digest ($REGISTRY/payments@$TRUSTED_DIGEST)"
  exit 1
fi
echo "$J" | jq -e '(.spec.template.spec.containers | length == 1) and .spec.replicas == 1 and .metadata.name == "payments"' >/dev/null \
  || { echo "❌ The manifest was changed beyond the image"; exit 1; }

echo "✅ deployment.yaml uses the verified image pinned by digest"
exit 0
