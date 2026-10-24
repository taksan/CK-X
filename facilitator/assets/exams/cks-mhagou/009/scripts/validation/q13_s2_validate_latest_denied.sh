#!/bin/bash
# Item: by behaviour, Pods whose image has the latest tag or no tag are rejected in registry-gate

source "$(dirname "$0")/../lib/vap_q13.sh"

# an admission policy takes a few seconds to be enforced
for i in $(seq 1 12); do
  OUT=$(try_pod registry-gate nginx:latest)
  denied "$OUT" && break
  sleep 3
done

denied "$OUT" || { echo "❌ A Pod with the image nginx:latest is accepted in registry-gate"; exit 1; }
denied "$(try_pod registry-gate registry.k8s.io/pause)" || { echo "❌ A Pod with an image without a tag (registry.k8s.io/pause) is accepted in registry-gate"; exit 1; }

echo "✅ Images tagged latest or without a tag are rejected in registry-gate"
exit 0
