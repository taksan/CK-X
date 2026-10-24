#!/bin/bash
# Validate by reading the process state inside the Pods that the Pods of build-agent run hardened: not root, no privilege
# escalation, only the allowed capability (or none), read-only root filesystem

NS="sandbox"
J=$(kubectl get deployment build-agent -n "$NS" -o json 2>/dev/null)
[ -n "$J" ] || { echo "❌ Deployment 'build-agent' not found in namespace '$NS'"; exit 1; }

WANT=$(echo "$J" | jq -r '.spec.replicas')
ST=$(echo "$J" | jq -r '"\(.status.updatedReplicas // 0)/\(.status.readyReplicas // 0)/\(.status.replicas // 0)"')
if [ "$ST" != "$WANT/$WANT/$WANT" ]; then
  echo "❌ The rollout is not complete or the Pods are not ready ($ST, expected $WANT of each): does the container still run with a read-only filesystem?"
  exit 1
fi

PODS=$(kubectl get pods -n "$NS" -l app=build-agent -o json | jq -r '.items[] | select(.metadata.deletionTimestamp == null and .status.phase == "Running") | .metadata.name')
[ -n "$PODS" ] || { echo "❌ No running Pod"; exit 1; }

for pod in $PODS; do
  UID_=$(kubectl exec -n "$NS" "$pod" -- id -u 2>/dev/null)
  if [ -z "$UID_" ] || [ "$UID_" = "0" ]; then
    echo "❌ Pod $pod runs as root"
    exit 1
  fi
  STATUS=$(kubectl exec -n "$NS" "$pod" -- cat /proc/1/status 2>/dev/null)
  CAP=$(echo "$STATUS" | awk '/^CapBnd:/ {print $2}')
  case "$CAP" in
    0000000000000000|0000000000000400) ;;
    *) echo "❌ Pod $pod keeps Linux capabilities (CapBnd=$CAP): drop ALL, only NET_BIND_SERVICE may remain"; exit 1;;
  esac
  [ "$(echo "$STATUS" | awk '/^NoNewPrivs:/ {print $2}')" = "1" ] || { echo "❌ Pod $pod can gain privileges (allowPrivilegeEscalation must be false)"; exit 1; }
  if ! kubectl exec -n "$NS" "$pod" -- cat /proc/mounts 2>/dev/null | awk '$2 == "/" {print $4}' | grep -qE '(^|,)ro(,|$)'; then
    echo "❌ The root filesystem of Pod $pod is writable (readOnlyRootFilesystem must be true)"
    exit 1
  fi
done

echo "✅ build-agent runs as a non-root user, without capabilities or privilege escalation, with a read-only root filesystem"
exit 0
