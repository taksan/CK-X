#!/bin/bash
# The configuration is active in the RUNNING kube-apiserver (process command line and a log file
# with recent events) and the API server is healthy

source "$(dirname "$0")/../lib/nodes.sh"

NODE="$CONTROL_PLANE"
LOG="/etc/kubernetes/audit/logs/audit.log"

kubectl get --raw /readyz >/dev/null 2>&1 || { echo "❌ The API server is not ready"; exit 1; }

PS=$(ssh -o StrictHostKeyChecking=no "$NODE" "pgrep -a kube-apiserver | head -1" 2>/dev/null)
for flag in "--audit-policy-file=/etc/kubernetes/audit/policy.yaml" "--audit-log-path=$LOG" "--audit-log-maxsize=500" "--audit-log-maxbackup=5" "--audit-log-maxage=7"; do
  echo "$PS" | grep -q -- "$flag" || { echo "❌ The running kube-apiserver process does not use $flag (was the manifest saved and the API server restarted?)"; exit 1; }
done

LAST=""
for i in $(seq 1 10); do
  LAST=$(ssh -o StrictHostKeyChecking=no "$NODE" "tail -n 20 '$LOG' 2>/dev/null | tail -n 1" 2>/dev/null | jq -r '.requestReceivedTimestamp // empty' 2>/dev/null)
  if [ -n "$LAST" ]; then
    AGE=$(( $(date -u +%s) - $(date -u -d "$LAST" +%s 2>/dev/null || echo 0) ))
    [ "$AGE" -lt 120 ] && break
  fi
  LAST=""
  sleep 3
done
[ -n "$LAST" ] || { echo "❌ $LOG does not exist on the control plane or has no recent audit events"; exit 1; }

echo "✅ The audit configuration is active in the running API server and events are written to $LOG"
exit 0
