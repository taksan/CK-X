#!/bin/bash
# Item: a scanner-approved image is still admitted (credited once the vulnerable image is rejected)

for i in $(seq 1 30); do kubectl get --raw /readyz >/dev/null 2>&1 && break; sleep 4; done

BAD=$(kubectl run ckx-scan-probe --image=nginx:1.16 --restart=Never -n scanner-lab --dry-run=server 2>&1)
echo "$BAD" | grep -qi 'image policy webhook' || { echo "❌ The scanner does not reject the vulnerable image yet: nothing to credit"; exit 1; }

OUT=$(kubectl run ckx-scan-probe --image=registry.k8s.io/pause:3.10 --restart=Never -n scanner-lab --dry-run=server 2>&1)
if echo "$OUT" | grep -qi 'forbidden\|image policy webhook\|error'; then
  echo "❌ The approved image registry.k8s.io/pause:3.10 is rejected: $(echo "$OUT" | head -1 | cut -c1-140)"
  exit 1
fi

echo "✅ The approved image is admitted"
exit 0
