#!/bin/bash
# Source this file (question 8): reads the SBOM of the candidate, in SPDX JSON or SPDX tag-value.
# Sets SBOM_FORMAT (json|tagvalue), SBOM_FILE, or prints the reason and returns 1.

SBOM_FILE="${Q8_FILE:-/tmp/exam/mhagou-003-q8/sbom.spdx}"
SBOM_FORMAT=""

load_sbom() {
  [ -s "$SBOM_FILE" ] || { echo "❌ $SBOM_FILE does not exist or is empty"; return 1; }
  if jq -e '(.spdxVersion // "") | startswith("SPDX-")' "$SBOM_FILE" >/dev/null 2>&1; then
    SBOM_FORMAT="json"
  elif head -n 20 "$SBOM_FILE" | grep -q '^SPDXVersion: SPDX-'; then
    SBOM_FORMAT="tagvalue"
  else
    echo "❌ $SBOM_FILE is neither an SPDX JSON nor an SPDX tag-value document"
    return 1
  fi
}
