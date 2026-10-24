#!/bin/bash
# Item: secure-app uses the Localhost profile profiles/block-debug.json (every container, not
# privileged), is Running and Ready and its web server still answers on port 80

source "$(dirname "$0")/../lib/seccomp-q6.sh"

J=$(q6_pod_json)
[ -n "$J" ] || { echo "❌ Pod secure-app not found in namespace $Q6_NS (it must be re-created, not deleted)"; exit 1; }

echo "$J" | jq -e '.spec as $s | all(($s.containers + ($s.initContainers // []))[];
    (.securityContext.privileged // false) == false and
    ((.securityContext.seccompProfile // $s.securityContext.seccompProfile) | .type == "Localhost" and .localhostProfile == "profiles/block-debug.json"))' >/dev/null \
  || { echo "❌ The containers of the Pod do not all use the Localhost profile profiles/block-debug.json"; exit 1; }

echo "$J" | jq -e '.metadata.deletionTimestamp == null and .status.phase == "Running" and any(.status.conditions[]?; .type == "Ready" and .status == "True")' >/dev/null \
  || { echo "❌ The Pod is not Running and Ready (phase: $(echo "$J" | jq -r '.status.phase')): does the profile exist on its node?"; exit 1; }

kubectl exec -n "$Q6_NS" secure-app -c "$(echo "$J" | jq -r '.spec.containers[0].name')" -- wget -q -T 5 -O /dev/null http://127.0.0.1:80/ >/dev/null 2>&1 \
  || { echo "❌ The web server of the Pod does not answer on port 80: the Pod must remain functional"; exit 1; }

echo "✅ secure-app runs with profiles/block-debug.json and answers on port 80"
exit 0
