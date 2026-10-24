#!/bin/bash
# Item: sbom.spdx.json is an SPDX-JSON SBOM of the image of the Pod kiwi

F="${Q4_DIR:-/tmp/exam/mhagou-007-q4}/sbom.spdx.json"
[ -s "$F" ] || { echo "❌ $F does not exist or is empty"; exit 1; }
IMAGE=$(kubectl get pod kiwi -n sbom-lab -o jsonpath='{.spec.containers[0].image}' 2>/dev/null)
[ -n "$IMAGE" ] || { echo "❌ Pod kiwi not found in namespace sbom-lab: it must not be deleted"; exit 1; }

jq -e '.spdxVersion | startswith("SPDX-")' "$F" >/dev/null 2>&1 || { echo "❌ $F is not an SPDX-JSON document"; exit 1; }
jq -e --arg i "$IMAGE" '(.name == $i) or ([.packages[]?.name] | any(. == "nginx" or . == $i))' "$F" >/dev/null 2>&1 \
  || { echo "❌ The SBOM is not for the image of the Pod kiwi ($IMAGE)"; exit 1; }
N=$(jq '.packages | length' "$F")
[ "${N:-0}" -ge 50 ] || { echo "❌ The SBOM lists only ${N:-0} packages: it must describe the whole image"; exit 1; }

echo "✅ sbom.spdx.json is an SPDX-JSON SBOM of $IMAGE ($N packages)"
exit 0
