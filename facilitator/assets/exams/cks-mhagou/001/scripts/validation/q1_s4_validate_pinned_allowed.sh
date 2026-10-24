#!/bin/bash
# Item (by behaviour): Pods with a pinned image are still admitted by the working webhook
# (credited only when the webhook is enforcing: a "latest" image is denied)

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
echo "$OUT" | grep -qi 'image policy webhook' || { echo "❌ The webhook is not enforcing yet (a latest image is not denied)"; exit 1; }

OUT=$(try "docker.io/library/ckx$RANDOM$RANDOM:1.0")
if echo "$OUT" | grep -qi 'forbidden\|image policy webhook'; then
  echo "❌ A Pod with a pinned image is rejected ($(echo "$OUT" | head -1 | cut -c1-140)): is the webhook reachable?"
  exit 1
fi
OUT=$(try "docker.io/library/busybox@sha256:$(printf '%064d' $RANDOM)")
echo "$OUT" | grep -qi 'forbidden\|image policy webhook' && { echo "❌ A Pod with an image pinned by digest is rejected"; exit 1; }

echo "✅ Pods with pinned images are admitted"
exit 0
