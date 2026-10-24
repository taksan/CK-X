#!/bin/bash
# Validate the report covers the three images that were asked to be scanned

REPORT="${Q3_REPORT:-/tmp/exam/cks-003-q3/trivy-vulnerable.txt}"
IMAGES=("httpd:2.4.49" "postgres:12" "alpine:3.12")

if [ ! -s "$REPORT" ]; then
  echo "❌ Report '$REPORT' not found or empty"
  exit 1
fi

for img in "${IMAGES[@]}"; do
  # table output has a "<image> (<os>)" heading, JSON output has "ArtifactName"
  if ! grep -Fq -e "$img (" -e "\"ArtifactName\": \"$img\"" -e "\"ArtifactName\":\"$img\"" "$REPORT"; then
    echo "❌ The report has no scan of '$img'"
    exit 1
  fi
done

if ! grep -q "CVE-" "$REPORT"; then
  echo "❌ The report does not list any CVE"
  exit 1
fi

echo "✅ The report contains the scan of all three images"
exit 0
