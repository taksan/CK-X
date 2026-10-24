#!/bin/bash
# Source this file. Question 9: trigger a shell with a terminal in the Pod worker-pod (namespace
# space, on node02) and capture the alert that the Falco service of node02 writes to its journal.
#
#   falco_shell_alert   sets ALERT_OUTPUT (the output text of the alert, after the priority) and
#                       ALERT_CID (12 characters container id of the Pod), or prints the reason and
#                       returns 1. The container id comes from the Pod status, not from the alert.

source "$(dirname "${BASH_SOURCE[0]}")/nodes.sh"
FALCO_NODE="${NODE02}"
FALCO_NS="space"
FALCO_POD="worker-pod"

falco_shell_alert() {
  local cid since attempt line
  cid=$(kubectl get pod "$FALCO_POD" -n "$FALCO_NS" -o jsonpath='{.status.containerStatuses[0].containerID}' 2>/dev/null | sed 's#.*://##' | cut -c1-12)
  if [ -z "$cid" ]; then
    echo "❌ Pod $FALCO_POD of the namespace $FALCO_NS is not running"
    return 1
  fi
  ALERT_CID="$cid"
  if ! ssh -o StrictHostKeyChecking=no "$FALCO_NODE" "systemctl is-active --quiet falco-modern-bpf" 2>/dev/null; then
    echo "❌ The Falco service of $FALCO_NODE is not running (was it restarted after the change?)"
    return 1
  fi

  for attempt in 1 2 3 4 5 6; do
    since=$(ssh -o StrictHostKeyChecking=no "$FALCO_NODE" "date '+%Y-%m-%d %H:%M:%S'" 2>/dev/null)
    # a real terminal is needed for the rule: run kubectl exec -it under script(1)
    script -qec "kubectl exec -it -n $FALCO_NS $FALCO_POD -- sh -c 'true'" /dev/null >/dev/null 2>&1 < /dev/null
    for i in 1 2 3 4; do
      sleep 2
      line=$(ssh -o StrictHostKeyChecking=no "$FALCO_NODE" "journalctl -u falco-modern-bpf --since '$since' --no-pager -o cat 2>/dev/null | grep -F '$cid' | grep -E ': (Emergency|Alert|Critical|Error|Warning|Notice|Informational|Debug) ' | grep -v 'Executing binary' | tail -1" 2>/dev/null)
      [ -n "$line" ] && break 2
    done
  done

  if [ -z "$line" ]; then
    echo "❌ No Falco alert for a shell in the container of $FALCO_POD was found in the journal of $FALCO_NODE"
    return 1
  fi
  ALERT_OUTPUT=$(echo "$line" | sed -E 's/^.*: (Emergency|Alert|Critical|Error|Warning|Notice|Informational|Debug) //')
  return 0
}
