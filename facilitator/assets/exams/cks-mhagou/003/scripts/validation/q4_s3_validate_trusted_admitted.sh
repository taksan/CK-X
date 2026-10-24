#!/bin/bash
# Validate by behaviour: Pods with other images are still admitted by the working webhook
# (the webhook must also be enforcing: without a denial of untrusted/ there is nothing to credit)

for i in $(seq 1 30); do kubectl get --raw /readyz >/dev/null 2>&1 && break; sleep 4; done

pod() { cat <<EOF
apiVersion: v1
kind: Pod
metadata: {name: ckx-probe}
spec:
  containers: [{name: c, image: "$1", command: [sleep, "60"]}]
EOF
}
try() { pod "$1" | kubectl create -n image-gate --dry-run=server -f - 2>&1; }

OUT=$(try "docker.io/untrusted/ckx$RANDOM$RANDOM:1.0")
echo "$OUT" | grep -qi 'image policy webhook' || { echo "❌ The webhook is not enforcing yet (an image from untrusted/ is not denied)"; exit 1; }

OUT=$(try "docker.io/library/ckx$RANDOM$RANDOM:1.0")
if echo "$OUT" | grep -qi 'forbidden\|image policy webhook'; then
  echo "❌ A Pod with a normal image is rejected ($(echo "$OUT" | head -1 | cut -c1-140)): is the webhook URL of kubeconf correct?"
  exit 1
fi
OUT=$(try "docker.io/library/busybox:latest")
echo "$OUT" | grep -qi 'forbidden\|image policy webhook' && { echo "❌ A Pod with busybox:latest is rejected: only untrusted/ images must be denied"; exit 1; }

echo "✅ Pods with other images are admitted"
exit 0
