#!/bin/bash
# Validate kubesec gives the manifest a score of at least 4 points

MANIFEST="${Q6_MANIFEST:-/tmp/exam/cks-003-q6/kubesec-test.yaml}"
KUBESEC="${KUBESEC_BIN:-kubesec}"

if [ ! -s "$MANIFEST" ]; then
  echo "❌ Manifest '$MANIFEST' not found"
  exit 1
fi

SCORE=$("$KUBESEC" scan "$MANIFEST" 2>/dev/null | jq -r '.[0].score // empty')
if [ -z "$SCORE" ]; then
  echo "❌ kubesec could not score the manifest"
  exit 1
fi

if [ "$SCORE" -lt 4 ]; then
  echo "❌ kubesec score is $SCORE, at least 4 is required"
  exit 1
fi

echo "✅ kubesec score is $SCORE (at least 4)"
exit 0
