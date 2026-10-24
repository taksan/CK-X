#!/bin/bash
# Validate by behaviour: a Pod whose image comes from an untrusted/ repository is denied by the webhook

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
echo "$OUT" | grep -qi 'image policy webhook' || { echo "❌ A Pod with an image from untrusted/ is not denied by the image policy webhook ($(echo "$OUT" | head -1 | cut -c1-120))"; exit 1; }
OUT=$(try "registry.example.org/untrusted/ckx$RANDOM$RANDOM:2.0")
echo "$OUT" | grep -qi 'image policy webhook' || { echo "❌ A Pod with an image from registry.example.org/untrusted/ is not denied by the image policy webhook"; exit 1; }

echo "✅ Images from untrusted/ repositories are denied by the webhook"
exit 0
