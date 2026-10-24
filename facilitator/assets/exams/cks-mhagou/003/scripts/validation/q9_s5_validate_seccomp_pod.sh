#!/bin/bash
# Validate the Pod nginx-secure in secure-team: Running with the Localhost profile profiles/audit.json
# (pod level or container level) and its process is really confined (Seccomp: 2)

NS="secure-team"
J=$(kubectl get pod nginx-secure -n "$NS" -o json 2>/dev/null)
[ -n "$J" ] || { echo "❌ Pod 'nginx-secure' not found in namespace '$NS'"; exit 1; }

echo "$J" | jq -e '
  ((.spec.securityContext.seccompProfile // {}) as $p | ($p.type == "Localhost" and $p.localhostProfile == "profiles/audit.json"))
  or ([.spec.containers[].securityContext.seccompProfile // {} | select(.type == "Localhost" and .localhostProfile == "profiles/audit.json")] | length > 0)' >/dev/null \
  || { echo "❌ Pod 'nginx-secure' does not use the Localhost seccomp profile profiles/audit.json"; exit 1; }

[ "$(echo "$J" | jq -r '.status.phase')" = "Running" ] || { echo "❌ Pod 'nginx-secure' is not running (phase $(echo "$J" | jq -r '.status.phase')): is the profile on the node where it is scheduled?"; exit 1; }

MODE=$(kubectl exec -n "$NS" nginx-secure -- sh -c "grep '^Seccomp:' /proc/1/status" 2>/dev/null | awk '{print $2}')
[ "$MODE" = "2" ] || { echo "❌ The process of the Pod has Seccomp mode '${MODE:-?}', expected 2 (filter)"; exit 1; }

echo "✅ Pod nginx-secure runs confined by profiles/audit.json"
exit 0
