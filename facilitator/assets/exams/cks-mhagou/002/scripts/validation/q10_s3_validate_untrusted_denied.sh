#!/bin/bash
# By behaviour: a Pod with an image of the registry untrusted.example.com is denied by the webhook

for i in $(seq 1 30); do kubectl get --raw /readyz >/dev/null 2>&1 && break; sleep 4; done

pod() { cat <<EOF
apiVersion: v1
kind: Pod
metadata: {name: ckx-probe}
spec:
  containers: [{name: c, image: "$1", command: [sleep, "60"]}]
EOF
}
try() { pod "$1" | kubectl create -n image-review --dry-run=server -f - 2>&1; }

OUT=$(try "untrusted.example.com/ckx$RANDOM$RANDOM/app:1.0")
echo "$OUT" | grep -qi 'image policy webhook' || { echo "❌ A Pod with an image of untrusted.example.com is not denied by the image policy webhook ($(echo "$OUT" | head -1 | cut -c1-120))"; exit 1; }

echo "✅ Images of untrusted.example.com are denied by the webhook"
exit 0
