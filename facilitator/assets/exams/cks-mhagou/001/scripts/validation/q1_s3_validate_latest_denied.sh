#!/bin/bash
# Item (by behaviour): a Pod whose image is tagged latest (or has no tag) is denied by the image policy webhook

source "$(dirname "$0")/../lib/apiserver.sh"
wait_api_ready 150 || { echo "❌ The API server is not ready"; exit 1; }

pod() { cat <<EOF
apiVersion: v1
kind: Pod
metadata: {name: ckx-probe}
spec:
  containers: [{name: c, image: "$1", command: [sleep, "60"]}]
EOF
}
try() { pod "$1" | kubectl create -n webhook-lab --dry-run=server -f - 2>&1; }

OUT=$(try "docker.io/library/ckx$RANDOM$RANDOM:latest")
echo "$OUT" | grep -qi 'image policy webhook' || { echo "❌ A Pod with an image tagged latest is not denied by the image policy webhook ($(echo "$OUT" | head -1 | cut -c1-120))"; exit 1; }
OUT=$(try "docker.io/library/ckx$RANDOM$RANDOM")
echo "$OUT" | grep -qi 'image policy webhook' || { echo "❌ A Pod with an image without a tag is not denied by the image policy webhook"; exit 1; }

echo "✅ Images tagged latest or without a tag are denied by the webhook"
exit 0
