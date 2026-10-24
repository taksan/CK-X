#!/bin/bash
# sbom1.json: SPDX-JSON SBOM of the image alpine:3.20.3

F="${Q15_DIR:-/tmp/exam/mhagou-006-q15}/sbom1.json"
[ -s "$F" ] || { echo "❌ $F does not exist or is empty"; exit 1; }
jq -e '.spdxVersion | startswith("SPDX-")' "$F" >/dev/null 2>&1 || { echo "❌ $F is not an SPDX-JSON document"; exit 1; }
jq -e '.name | test("alpine")' "$F" >/dev/null 2>&1 || { echo "❌ The SBOM is not for the image alpine"; exit 1; }
grep -q '3\.20\.3' "$F" || { echo "❌ The SBOM is not for the version 3.20.3 of alpine"; exit 1; }

echo "✅ sbom1.json is an SPDX-JSON SBOM of alpine:3.20.3"
exit 0
