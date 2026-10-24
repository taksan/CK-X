#!/bin/bash
# Validate the Pod web in kubesec-lab runs, its live object scores at least 12 with kubesec, and the
# container really runs unprivileged (uid != 0, read-only root filesystem)

NS="kubesec-lab"
J=$(kubectl get pod web -n "$NS" -o json 2>/dev/null)
[ -n "$J" ] || { echo "❌ Pod 'web' not found in namespace '$NS'"; exit 1; }
[ "$(echo "$J" | jq -r '.status.phase')" = "Running" ] || { echo "❌ Pod 'web' is not running (phase $(echo "$J" | jq -r '.status.phase')): is the image able to run with these settings?"; exit 1; }

S=$(echo "$J" | kubesec scan - 2>/dev/null)
SCORE=$(echo "$S" | jq -r '.[0].score // empty' 2>/dev/null)
[ -n "$SCORE" ] && [ "$SCORE" -ge 12 ] 2>/dev/null || { echo "❌ The live Pod scores ${SCORE:-n/a} with kubesec, expected at least 12 (was the improved manifest applied?)"; exit 1; }

UID_=$(kubectl exec -n "$NS" web -- id -u 2>/dev/null)
[ -n "$UID_" ] && [ "$UID_" != "0" ] || { echo "❌ The container runs as root"; exit 1; }
kubectl exec -n "$NS" web -- cat /proc/mounts 2>/dev/null | awk '$2 == "/" {print $4}' | grep -qE '(^|,)ro(,|$)' \
  || { echo "❌ The root filesystem of the container is writable"; exit 1; }

echo "✅ Pod web runs unprivileged with a read-only root filesystem and scores $SCORE with kubesec"
exit 0
