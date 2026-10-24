#!/bin/bash
# By behaviour: nginx-auditing is Running and its process is confined by a seccomp filter
# (Seccomp: 2 in /proc/1/status; without a profile it would be 0)

source "$(dirname "$0")/../lib/nodes.sh"
NS="alpha"
PHASE=$(kubectl get pod nginx-auditing -n "$NS" -o jsonpath='{.status.phase}' 2>/dev/null)
[ "$PHASE" = "Running" ] || { echo "❌ Pod 'nginx-auditing' is not running (phase '${PHASE:-none}'): does the profile file exist on ${NODE01}?"; exit 1; }

MODE=$(kubectl exec -n "$NS" nginx-auditing -- sh -c "grep '^Seccomp:' /proc/1/status" 2>/dev/null | awk '{print $2}')
[ "$MODE" = "2" ] || { echo "❌ The container process has Seccomp mode '${MODE:-?}', expected 2 (a profile applied)"; exit 1; }

echo "✅ The container of nginx-auditing is confined by a seccomp filter"
exit 0
