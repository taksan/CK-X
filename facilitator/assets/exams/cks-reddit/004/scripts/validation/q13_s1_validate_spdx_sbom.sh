#!/bin/bash
# Validate sbom1.json: SPDX-JSON SBOM of registry.k8s.io/pause:3.9

F="${Q13_DIR:-/tmp/exam/cks-004-q13}/sbom1.json"
[ -s "$F" ] || { echo "❌ $F does not exist or is empty"; exit 1; }

jq -e '.spdxVersion | startswith("SPDX-")' "$F" >/dev/null 2>&1 || { echo "❌ $F is not an SPDX-JSON document"; exit 1; }
jq -e '[.name, (.packages[]?.name)] | any(test("pause"))' "$F" >/dev/null 2>&1 || { echo "❌ The SBOM is not for the image registry.k8s.io/pause:3.9"; exit 1; }
jq -e '.name | test("3.9|pause")' "$F" >/dev/null 2>&1 || { echo "❌ The SBOM is not for the image registry.k8s.io/pause:3.9"; exit 1; }

echo "✅ sbom1.json is an SPDX-JSON SBOM of registry.k8s.io/pause:3.9"
exit 0
