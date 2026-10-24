#!/bin/bash
# Validate the manifest /tmp/exam/mhagou-003-q5/pod.yaml: kubesec scores it at least 12 with no
# critical advice, and it is still the same Pod (name, namespace, image)

F="${Q5_FILE:-/tmp/exam/mhagou-003-q5/pod.yaml}"
[ -s "$F" ] || { echo "❌ $F does not exist or is empty"; exit 1; }

J=$(kubesec scan "$F" 2>/dev/null)
[ -n "$J" ] && echo "$J" | jq -e '.[0].valid == true' >/dev/null 2>&1 \
  || { echo "❌ kubesec cannot scan $F as a valid Pod manifest"; exit 1; }

SCORE=$(echo "$J" | jq -r '.[0].score')
CRIT=$(echo "$J" | jq -r '[.[0].scoring.critical[]?.id] | join(",")')
[ -z "$CRIT" ] || { echo "❌ kubesec reports critical issues: $CRIT"; exit 1; }
[ "$SCORE" -ge 12 ] 2>/dev/null || { echo "❌ The kubesec score of $F is $SCORE, expected at least 12 (see 'kubesec scan' advice)"; exit 1; }

kubectl create --dry-run=client -o json -f "$F" 2>/dev/null | jq -e '.metadata.name == "web" and .metadata.namespace == "kubesec-lab" and .spec.containers[0].image == "nginxinc/nginx-unprivileged:1.27-alpine"' >/dev/null \
  || { echo "❌ The manifest is no longer the Pod 'web' in kubesec-lab with the image nginxinc/nginx-unprivileged:1.27-alpine"; exit 1; }

echo "✅ kubesec scores $F at $SCORE with no critical advice"
exit 0
