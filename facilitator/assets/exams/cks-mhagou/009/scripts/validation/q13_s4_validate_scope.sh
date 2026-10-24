#!/bin/bash
# Item: the policy applies to registry-gate only (credited once latest is rejected there)

source "$(dirname "$0")/../lib/vap_q13.sh"

denied "$(try_pod registry-gate nginx:latest)" || { echo "❌ latest images are not rejected yet: nothing to credit"; exit 1; }

OUT=$(try_pod kube-public nginx:latest)
denied "$OUT" && { echo "❌ The policy also rejects images tagged latest in another namespace (kube-public): scope it to registry-gate"; exit 1; }

echo "✅ The policy is limited to registry-gate"
exit 0
