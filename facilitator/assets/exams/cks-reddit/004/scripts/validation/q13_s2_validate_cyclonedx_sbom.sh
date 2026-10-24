#!/bin/bash
# Validate sbom2.json: CycloneDX SBOM of alpine:3.20

F="${Q13_DIR:-/tmp/exam/cks-004-q13}/sbom2.json"
[ -s "$F" ] || { echo "❌ $F does not exist or is empty"; exit 1; }

jq -e '.bomFormat == "CycloneDX"' "$F" >/dev/null 2>&1 || { echo "❌ $F is not a CycloneDX document"; exit 1; }
jq -e '.metadata.component.name | test("alpine")' "$F" >/dev/null 2>&1 || { echo "❌ The SBOM is not for the image alpine:3.20"; exit 1; }
if ! grep -q '3\.20' "$F"; then
  echo "❌ The SBOM is not for the version 3.20 of alpine"
  exit 1
fi

echo "✅ sbom2.json is a CycloneDX SBOM of alpine:3.20"
exit 0
