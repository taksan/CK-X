#!/bin/bash
# Item: Pods with a pinned image (tag or digest) are still accepted (credited once latest is rejected)

source "$(dirname "$0")/../lib/vap_q13.sh"

denied "$(try_pod registry-gate nginx:latest)" || { echo "❌ latest images are not rejected yet: nothing to credit"; exit 1; }

OUT=$(try_pod registry-gate registry.k8s.io/pause:3.10)
denied "$OUT" && { echo "❌ A Pod with a tagged image (registry.k8s.io/pause:3.10) is rejected: $(echo "$OUT" | head -1 | cut -c1-140)"; exit 1; }
DIGEST="registry.k8s.io/pause@sha256:$(printf '%064d' 7)"
OUT=$(try_pod registry-gate "$DIGEST")
denied "$OUT" && { echo "❌ A Pod with an image pinned by digest is rejected: $(echo "$OUT" | head -1 | cut -c1-140)"; exit 1; }

echo "✅ Pinned images are accepted"
exit 0
