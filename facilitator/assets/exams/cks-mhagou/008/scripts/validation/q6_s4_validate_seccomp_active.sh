#!/bin/bash
# Item: seccomp filtering is really active in the container processes (Seccomp: 2)

source "$(dirname "$0")/../lib/seccomp-q6.sh"

J=$(q6_pod_json)
[ -n "$J" ] || { echo "❌ Pod secure-app not found in namespace $Q6_NS"; exit 1; }
[ "$(echo "$J" | jq -r '.status.phase')" = "Running" ] || { echo "❌ The Pod is not running"; exit 1; }

for c in $(echo "$J" | jq -r '.spec.containers[].name'); do
  MODE=$(kubectl exec -n "$Q6_NS" secure-app -c "$c" -- sh -c "grep '^Seccomp:' /proc/1/status" 2>/dev/null | awk '{print $2}')
  [ "$MODE" = "2" ] || { echo "❌ Container $c has Seccomp mode '${MODE:-unknown}', expected 2 (filter): the profile is not applied"; exit 1; }
done

echo "✅ A seccomp filter is active in every container"
exit 0
