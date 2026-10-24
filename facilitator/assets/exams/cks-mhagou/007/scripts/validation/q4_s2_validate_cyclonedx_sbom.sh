#!/bin/bash
# Item: sbom.cdx.json is a CycloneDX SBOM of the image of the Pod kiwi

F="${Q4_DIR:-/tmp/exam/mhagou-007-q4}/sbom.cdx.json"
[ -s "$F" ] || { echo "❌ $F does not exist or is empty"; exit 1; }
IMAGE=$(kubectl get pod kiwi -n sbom-lab -o jsonpath='{.spec.containers[0].image}' 2>/dev/null)
[ -n "$IMAGE" ] || { echo "❌ Pod kiwi not found in namespace sbom-lab: it must not be deleted"; exit 1; }

jq -e '.bomFormat == "CycloneDX"' "$F" >/dev/null 2>&1 || { echo "❌ $F is not a CycloneDX JSON document"; exit 1; }
jq -e --arg i "$IMAGE" '(.metadata.component.name // "") | (. == $i) or startswith("nginx")' "$F" >/dev/null 2>&1 \
  || { echo "❌ The SBOM is not for the image of the Pod kiwi ($IMAGE)"; exit 1; }
N=$(jq '.components | length' "$F")
[ "${N:-0}" -ge 50 ] || { echo "❌ The SBOM lists only ${N:-0} components: it must describe the whole image"; exit 1; }

echo "✅ sbom.cdx.json is a CycloneDX SBOM of $IMAGE ($N components)"
exit 0
