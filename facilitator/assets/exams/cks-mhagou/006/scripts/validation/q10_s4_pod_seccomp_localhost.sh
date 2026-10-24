#!/bin/bash
# Pod audit-pod uses a Localhost seccomp profile, privilege escalation is disabled and the running
# process has a seccomp filter (Seccomp: 2) and no_new_privs

source "$(dirname "$0")/../lib/nodes.sh"

source "$(dirname "$0")/../lib/runtime-q10.sh"
J=$(kubectl get pod audit-pod -n "$NS" -o json 2>/dev/null)
[ -n "$J" ] || { echo "❌ Pod 'audit-pod' not found in namespace '$NS'"; exit 1; }
[ "$(echo "$J" | jq -r '.status.phase')" = "Running" ] || { echo "❌ Pod 'audit-pod' is not running (does the profile file exist on $NODE01?)"; exit 1; }

P=$(echo "$J" | jq -r '((.spec.containers[] | select(.name == "test-container") | .securityContext.seccompProfile) // .spec.securityContext.seccompProfile) | if .type == "Localhost" then .localhostProfile else "" end')
[ -n "$P" ] || { echo "❌ Pod 'audit-pod' does not use a Localhost seccomp profile"; exit 1; }
[ "$(echo "$J" | jq -r '.spec.containers[] | select(.name == "test-container") | .securityContext.allowPrivilegeEscalation')" = "false" ] || { echo "❌ The container test-container does not set allowPrivilegeEscalation: false"; exit 1; }

pod_proc_state audit-pod test-container || { echo "❌ Cannot read the process state of the container on $NODE"; exit 1; }
echo "$STATUS" | awk '$1 == "Seccomp:" && $2 == 2 {ok = 1} END {exit !ok}' || { echo "❌ The running process has no seccomp filter (Seccomp: 2 expected)"; exit 1; }
echo "$STATUS" | awk '$1 == "NoNewPrivs:" && $2 == 1 {ok = 1} END {exit !ok}' || { echo "❌ The running process can gain privileges (NoNewPrivs: 1 expected)"; exit 1; }

echo "✅ Pod 'audit-pod' uses the Localhost profile $P, with a seccomp filter and no new privileges"
exit 0
