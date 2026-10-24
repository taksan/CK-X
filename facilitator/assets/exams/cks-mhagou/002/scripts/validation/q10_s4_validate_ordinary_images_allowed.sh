#!/bin/bash
# By behaviour: Pods with ordinary images are still admitted (the webhook backend is reached and
# answers "allowed"). Credited only when the webhook already denies the untrusted registry.

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
echo "$OUT" | grep -qi 'image policy webhook' || { echo "❌ The webhook is not enforcing yet (an image of untrusted.example.com is not denied)"; exit 1; }

OUT=$(try "docker.io/library/ckx$RANDOM$RANDOM:1.0")
if echo "$OUT" | grep -qi 'forbidden\|image policy webhook'; then
  echo "❌ A Pod with an ordinary image is rejected ($(echo "$OUT" | head -1 | cut -c1-140)): is the webhook reachable (server URL, CA)?"
  exit 1
fi
OUT=$(try "nginx")
echo "$OUT" | grep -qi 'forbidden\|image policy webhook' && { echo "❌ A Pod with the image nginx is rejected"; exit 1; }

echo "✅ Pods with ordinary images are still admitted"
exit 0
