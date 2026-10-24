#!/bin/bash
# Validate the manifest still describes Pod kubesec-demo and kubesec reports no critical finding

MANIFEST="${Q6_MANIFEST:-/tmp/exam/cks-003-q6/kubesec-test.yaml}"
KUBESEC="${KUBESEC_BIN:-kubesec}"

if [ ! -s "$MANIFEST" ]; then
  echo "❌ Manifest '$MANIFEST' not found"
  exit 1
fi

RESULT=$("$KUBESEC" scan "$MANIFEST" 2>/dev/null)
if [ -z "$RESULT" ] || ! echo "$RESULT" | jq -e '.[0].valid' >/dev/null 2>&1; then
  echo "❌ kubesec could not scan the manifest (is it still a valid Pod?)"
  exit 1
fi

# still the same Pod
if ! echo "$RESULT" | jq -e '.[0].object | startswith("Pod/kubesec-demo")' >/dev/null; then
  echo "❌ The manifest must still describe the Pod 'kubesec-demo'"
  exit 1
fi
if ! grep -q 'gcr.io/google-samples/node-hello:1.0' "$MANIFEST"; then
  echo "❌ The container image must not be changed"
  exit 1
fi

CRITICAL=$(echo "$RESULT" | jq -r '.[0].scoring.critical[]?.selector')
if [ -n "$CRITICAL" ]; then
  echo "❌ kubesec still reports critical findings:"
  echo "$CRITICAL" | sed 's/^/   /'
  exit 1
fi

echo "✅ kubesec reports no critical finding for Pod 'kubesec-demo'"
exit 0
