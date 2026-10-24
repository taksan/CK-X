#!/bin/bash
# Validate the saved ReplicaSet event lines and that the failure is real

NS="team-blue"
F="${Q16_FILE:-/tmp/exam/cks-004-q16/logs}"
[ -s "$F" ] || { echo "❌ $F does not exist or is empty"; exit 1; }

if ! grep -q 'FailedCreate' "$F" || ! grep -q 'violates PodSecurity "restricted' "$F" || ! grep -qi 'privileged' "$F"; then
  echo "❌ $F does not contain the FailedCreate event with the PodSecurity violation (privileged containers)"
  exit 1
fi

RS=$(kubectl get rs -n "$NS" -o json | jq -r '[.items[] | select(.metadata.ownerReferences[0].name == "privileged-runner")] | sort_by(.metadata.creationTimestamp) | last | .metadata.name')
EV=$(kubectl get events -n "$NS" --field-selector "involvedObject.name=$RS,reason=FailedCreate" -o jsonpath='{.items[*].message}' 2>/dev/null)
if ! echo "$EV" | grep -q 'violates PodSecurity "restricted'; then
  echo "❌ The ReplicaSet '$RS' has no FailedCreate event for a PodSecurity violation (was the Pod deleted after enforcing the label?)"
  exit 1
fi

echo "✅ $F contains the PodSecurity FailedCreate events of the ReplicaSet"
exit 0
