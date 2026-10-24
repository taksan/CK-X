#!/bin/bash
# sbom2.json: CycloneDX SBOM of the image busybox:1.36.1

F="${Q15_DIR:-/tmp/exam/mhagou-006-q15}/sbom2.json"
[ -s "$F" ] || { echo "❌ $F does not exist or is empty"; exit 1; }
jq -e '.bomFormat == "CycloneDX"' "$F" >/dev/null 2>&1 || { echo "❌ $F is not a CycloneDX document"; exit 1; }
jq -e '.metadata.component.name | test("busybox")' "$F" >/dev/null 2>&1 || { echo "❌ The SBOM is not for the image busybox"; exit 1; }
grep -q '1\.36\.1' "$F" || { echo "❌ The SBOM is not for the version 1.36.1 of busybox"; exit 1; }

echo "✅ sbom2.json is a CycloneDX SBOM of busybox:1.36.1"
exit 0
