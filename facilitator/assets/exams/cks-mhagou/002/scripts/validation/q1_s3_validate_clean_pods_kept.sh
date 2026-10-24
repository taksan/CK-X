#!/bin/bash
# The Pods without CRITICAL findings (comet: HIGH only, delta: none) must be kept. Credited only
# when the candidate really deleted something (otherwise "keep everything" would be a free mark).

NS="spectacle"
live() { kubectl get pod "$1" -n "$NS" -o json 2>/dev/null | jq -r 'select(.metadata.deletionTimestamp == null) | .metadata.name'; }

for p in comet delta; do
  [ -n "$(live "$p")" ] || { echo "❌ The Pod '$p' has no CRITICAL vulnerability (the task is about CRITICAL only) and was deleted"; exit 1; }
done
if [ -n "$(live atlas)" ] && [ -n "$(live beacon)" ]; then
  echo "❌ No Pod with CRITICAL vulnerabilities was deleted yet"
  exit 1
fi

echo "✅ The Pods without CRITICAL vulnerabilities were kept"
exit 0
