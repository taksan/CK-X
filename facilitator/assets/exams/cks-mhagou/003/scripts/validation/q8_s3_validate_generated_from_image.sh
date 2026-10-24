#!/bin/bash
# Validate the SBOM was really generated from the image: it lists its operating system packages
# (many of them, among them the nginx package of the 1.19 series)

source "$(dirname "$0")/../lib/sbom.sh"
load_sbom || exit 1

if [ "$SBOM_FORMAT" = "json" ]; then
  N=$(jq '.packages | length' "$SBOM_FILE" 2>/dev/null)
  NG=$(jq -r '[.packages[]? | select(.name == "nginx" and ((.versionInfo // "") | startswith("1.19")))] | length' "$SBOM_FILE" 2>/dev/null)
else
  N=$(grep -c '^PackageName:' "$SBOM_FILE")
  NG=$(awk '/^PackageName: nginx$/ {f=1; next} f && /^PackageVersion:/ {print ($2 ~ /^1\.19/) ? 1 : 0; f=0}' "$SBOM_FILE" | grep -c 1)
fi

[ "${N:-0}" -ge 50 ] || { echo "❌ The SBOM lists only ${N:-0} packages: it was not generated from the image (expected the OS packages of nginx:1.19, 50 or more)"; exit 1; }
[ "${NG:-0}" -ge 1 ] || { echo "❌ The SBOM has no 'nginx' package of version 1.19.x: is it the SBOM of nginx:1.19?"; exit 1; }

echo "✅ The SBOM lists $N packages including nginx 1.19.x"
exit 0
