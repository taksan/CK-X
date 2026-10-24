#!/bin/bash
# Source this file: pod_proc_state POD CONTAINER sets PID, STATUS (/proc/PID/status) and ARMOR
# (AppArmor label of the process) for a container of a Pod of namespace kernel-lab on node01

source "$(dirname "${BASH_SOURCE[0]}")/nodes.sh"

NODE="$NODE01"
NS="kernel-lab"

pod_proc_state() {
  local pod="$1" cname="$2" id inspect
  id=$(kubectl get pod "$pod" -n "$NS" -o jsonpath="{.status.containerStatuses[?(@.name==\"$cname\")].containerID}" 2>/dev/null | sed 's#.*://##')
  [ -n "$id" ] || return 1
  inspect=$(ssh -o StrictHostKeyChecking=no "$NODE" "crictl inspect '$id'" 2>/dev/null) || return 1
  PID=$(echo "$inspect" | jq -r '.info.pid // empty')
  [ -n "$PID" ] || return 1
  STATUS=$(ssh -o StrictHostKeyChecking=no "$NODE" "cat /proc/$PID/status" 2>/dev/null)
  ARMOR=$(ssh -o StrictHostKeyChecking=no "$NODE" "cat /proc/$PID/attr/apparmor/current 2>/dev/null || cat /proc/$PID/attr/current" 2>/dev/null)
}
