#!/bin/bash
# Validate the report only lists HIGH and CRITICAL vulnerabilities

REPORT="${Q3_REPORT:-/tmp/exam/cks-003-q3/trivy-vulnerable.txt}"

if [ ! -s "$REPORT" ]; then
  echo "❌ Report '$REPORT' not found or empty"
  exit 1
fi

if ! grep -Eq '\bCRITICAL\b' "$REPORT" || ! grep -Eq '\bHIGH\b' "$REPORT"; then
  echo "❌ The report does not list both HIGH and CRITICAL vulnerabilities"
  exit 1
fi

# any other severity (table cell or JSON value) means the filter was not applied
if grep -Eq '(│|\|)[[:space:]]*(MEDIUM|LOW|UNKNOWN)[[:space:]]*(│|\|)|"Severity":[[:space:]]*"(MEDIUM|LOW|UNKNOWN)"|\((UNKNOWN|LOW|MEDIUM): [1-9]' "$REPORT"; then
  echo "❌ The report contains MEDIUM, LOW or UNKNOWN vulnerabilities: scan with --severity HIGH,CRITICAL"
  exit 1
fi

echo "✅ The report only lists HIGH and CRITICAL vulnerabilities"
exit 0
