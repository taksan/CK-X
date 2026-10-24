#!/bin/bash

# Setup for CKS-004 Question 13: SBOMs with trivy. Files only (jumphost), no namespace needed.
# sbom_check.json is an SPDX-JSON SBOM of an old nginx image, generated here (it has known
# vulnerabilities).

source "$(dirname "$0")/../lib/wait-cluster.sh"

DIR="/tmp/exam/cks-004-q13"
mkdir -p "${DIR:?}"
rm -f "${DIR:?}"/*

if ! trivy image --quiet --scanners vuln --format spdx-json --output "$DIR/sbom_check.json" nginx:1.16 >/dev/null 2>&1; then
  echo "WARNING: unable to generate sbom_check.json (trivy / network problem)"
  exit 1
fi

echo "Setup completed for CKS-004 Question 13 (files in $DIR)"
exit 0
