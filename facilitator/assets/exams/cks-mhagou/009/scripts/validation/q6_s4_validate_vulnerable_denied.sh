#!/bin/bash
# Item: a Pod with the vulnerable image is rejected by the scanner (server-side dry-run)

for i in $(seq 1 30); do kubectl get --raw /readyz >/dev/null 2>&1 && break; sleep 4; done

OUT=$(kubectl run ckx-scan-probe --image=nginx:1.16 --restart=Never -n scanner-lab --dry-run=server 2>&1)
if ! echo "$OUT" | grep -qi 'image policy webhook'; then
  echo "❌ A Pod with the vulnerable image nginx:1.16 is not rejected by the image policy webhook ($(echo "$OUT" | head -1 | cut -c1-140))"
  exit 1
fi
echo "$OUT" | grep -qi 'vulnerable image' || { echo "❌ The Pod is rejected, but not by the scanner verdict: $(echo "$OUT" | head -1 | cut -c1-140)"; exit 1; }

echo "✅ The vulnerable image is rejected by the scanner"
exit 0
