#!/bin/bash
# Validate the file is an SPDX document (JSON or tag-value) with a package list

source "$(dirname "$0")/../lib/sbom.sh"
load_sbom || exit 1

if [ "$SBOM_FORMAT" = "json" ]; then
  jq -e '(.packages | type == "array") and (.packages | length > 0) and (.SPDXID == "SPDXRef-DOCUMENT")' "$SBOM_FILE" >/dev/null 2>&1 \
    || { echo "❌ The SPDX JSON document has no packages"; exit 1; }
else
  grep -q '^PackageName:' "$SBOM_FILE" || { echo "❌ The SPDX tag-value document has no packages"; exit 1; }
fi

echo "✅ $SBOM_FILE is an SPDX ($SBOM_FORMAT) document with packages"
exit 0
