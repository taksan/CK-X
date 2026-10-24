#!/bin/bash
# Behaviour: the alert for the read of /tmp/mem contains the Pod name or the container id of the
# workload that made the read

source "$(dirname "$0")/../lib/nodes.sh"

NS="mem-watch"
NODE="$NODE01"

POD=$(kubectl get pod -n "$NS" -l app=compute-c -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
CID=$(kubectl get pod -n "$NS" -l app=compute-c -o jsonpath='{.items[0].status.containerStatuses[0].containerID}' 2>/dev/null | sed 's#.*://##' | cut -c1-12)
[ -n "$POD" ] && [ -n "$CID" ] || { echo "❌ The Pod of compute-c is not running"; exit 1; }

LINE=""
for i in $(seq 1 6); do
  T0=$(date -u +"%Y-%m-%d %H:%M:%S")
  kubectl exec -n "$NS" deploy/compute-c -- cat /tmp/mem >/dev/null 2>&1
  sleep 6
  LINE=$(ssh -o StrictHostKeyChecking=no "$NODE" "journalctl -u falco-modern-bpf --since '$T0' --no-pager 2>/dev/null | grep -F '/tmp/mem' | grep 'Warning' | head -1" 2>/dev/null)
  [ -n "$LINE" ] && break
done
[ -n "$LINE" ] || { echo "❌ No WARNING alert for /tmp/mem to inspect"; exit 1; }

if echo "$LINE" | grep -q -e "$POD" -e "$CID"; then
  echo "✅ The alert identifies the workload (Pod name or container id)"
  exit 0
fi
echo "❌ The alert does not say which Pod or container made the read (add %k8s.pod.name or %container.id to the output): $(echo "$LINE" | cut -c1-200)"
exit 1
