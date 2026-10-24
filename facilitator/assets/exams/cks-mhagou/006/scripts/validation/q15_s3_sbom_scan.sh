#!/bin/bash
# sbom_result.json: JSON scan of sbom_check.json with the severities HIGH and CRITICAL only

DIR="${Q15_DIR:-/tmp/exam/mhagou-006-q15}"
F="$DIR/sbom_result.json"
[ -s "$F" ] || { echo "❌ $F does not exist or is empty"; exit 1; }

jq -e '.SchemaVersion != null and (.Results | type == "array")' "$F" >/dev/null 2>&1 || { echo "❌ $F is not a trivy JSON report"; exit 1; }
jq -e '.ArtifactName | endswith("sbom_check.json")' "$F" >/dev/null 2>&1 || { echo "❌ The report is not a scan of sbom_check.json"; exit 1; }

N=$(jq '[.Results[]?.Vulnerabilities[]?] | length' "$F")
[ "${N:-0}" -gt 0 ] || { echo "❌ The report has no vulnerabilities"; exit 1; }
BAD=$(jq '[.Results[]?.Vulnerabilities[]? | select(.Severity != "HIGH" and .Severity != "CRITICAL")] | length' "$F")
[ "$BAD" = "0" ] || { echo "❌ The report contains $BAD vulnerabilities that are not HIGH or CRITICAL"; exit 1; }

echo "✅ sbom_result.json: $N HIGH/CRITICAL vulnerabilities from sbom_check.json"
exit 0
