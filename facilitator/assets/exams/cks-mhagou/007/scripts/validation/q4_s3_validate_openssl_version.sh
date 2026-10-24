#!/bin/bash
# Item: openssl-version.txt holds the version of the package openssl found in the SPDX SBOM

DIR="${Q4_DIR:-/tmp/exam/mhagou-007-q4}"
[ -s "$DIR/sbom.spdx.json" ] || { echo "❌ $DIR/sbom.spdx.json does not exist: the version is read from the SBOM"; exit 1; }
[ -s "$DIR/openssl-version.txt" ] || { echo "❌ $DIR/openssl-version.txt does not exist or is empty"; exit 1; }

EXPECTED=$(jq -r '[.packages[]? | select(.name == "openssl") | .versionInfo][0] // empty' "$DIR/sbom.spdx.json")
[ -n "$EXPECTED" ] || { echo "❌ The SPDX SBOM has no package named openssl"; exit 1; }
GOT=$(tr -d '[:space:]' < "$DIR/openssl-version.txt")
[ "$GOT" = "$EXPECTED" ] || { echo "❌ openssl-version.txt contains '$GOT', the SBOM lists the version of the package openssl as '$EXPECTED'"; exit 1; }

echo "✅ openssl-version.txt holds the version of the package openssl ($EXPECTED)"
exit 0
