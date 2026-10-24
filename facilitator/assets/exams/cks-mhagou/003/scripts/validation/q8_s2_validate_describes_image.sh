#!/bin/bash
# Validate the SBOM describes the image nginx:1.19 (document name, package name or package reference)

source "$(dirname "$0")/../lib/sbom.sh"
load_sbom || exit 1

if [ "$SBOM_FORMAT" = "json" ]; then
  jq -e '[.name, (.packages[]? | .name, (.externalRefs[]?.referenceLocator // empty))] | any(. != null and (tostring | test("nginx:1\\.19|tag=1\\.19")))' "$SBOM_FILE" >/dev/null 2>&1 \
    || { echo "❌ The SBOM does not describe the image nginx:1.19 (no document/package name or reference with nginx:1.19)"; exit 1; }
else
  grep -Eq -- '^(DocumentName|PackageName): .*nginx:1\.19|ExternalRef: .*tag=1\.19' "$SBOM_FILE" \
    || { echo "❌ The SBOM does not describe the image nginx:1.19 (no document/package name or reference with nginx:1.19)"; exit 1; }
fi

echo "✅ The SBOM describes the image nginx:1.19"
exit 0
