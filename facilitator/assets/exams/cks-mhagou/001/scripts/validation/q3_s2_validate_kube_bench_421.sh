#!/bin/bash
# Item (by behaviour): kube-bench check 4.2.1 (kubelet --anonymous-auth false) passes on node02
source "$(dirname "$0")/../lib/nodes.sh"

OUT=$(ssh -o StrictHostKeyChecking=no node02 'kube-bench run --targets node --check 4.2.1 --json 2>/dev/null' 2>/dev/null)
[ -n "$OUT" ] || { echo "❌ kube-bench could not be run on $NODE02"; exit 1; }

STATUS=$(echo "$OUT" | jq -r '[.Controls[]?.tests[]?.results[]? | select(.test_number == "4.2.1") | .status][0] // empty' 2>/dev/null)
[ "$STATUS" = "PASS" ] || { echo "❌ kube-bench check 4.2.1 on $NODE02 is '${STATUS:-not found}', expected PASS"; exit 1; }

echo "✅ kube-bench check 4.2.1 passes on $NODE02"
exit 0
