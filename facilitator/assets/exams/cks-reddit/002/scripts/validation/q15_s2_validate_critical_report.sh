#!/bin/bash
# Validate the CRITICAL-only Trivy report for the legacy-web image was saved

REPORT="/tmp/exam/cks-002-q15/legacy-web-critical.txt"

if [ ! -s "$REPORT" ]; then
  echo "❌ Report '$REPORT' not found or empty"
  exit 1
fi

if ! grep -q "nginx" "$REPORT"; then
  echo "❌ Report does not look like a scan of the nginx image"
  exit 1
fi

if ! grep -q "CVE-" "$REPORT" || ! grep -q "CRITICAL" "$REPORT"; then
  echo "❌ Report does not list CRITICAL CVEs"
  exit 1
fi

if grep -Eq '\b(HIGH|MEDIUM|LOW)\b' "$REPORT"; then
  echo "❌ Report contains non-CRITICAL severities"
  exit 1
fi

echo "✅ Report contains only CRITICAL vulnerabilities of the legacy-web image"
exit 0
