#!/bin/bash
# Source this file. Question 12 helpers: HTTP reachability of nginx-pod (namespace moon, port 80)

TARGET_NS="moon"
TARGET_POD="nginx-pod"

target_ip() { kubectl get pod "$TARGET_POD" -n "$TARGET_NS" -o jsonpath='{.status.podIP}' 2>/dev/null; }

# reach NAMESPACE POD  -> 0 when the Pod can open an HTTP connection to nginx-pod:80
reach() {
  local ip; ip=$(target_ip)
  [ -n "$ip" ] || return 2
  kubectl exec -n "$1" "$2" -- wget -q -T 3 -O /dev/null "http://$ip:80" >/dev/null 2>&1
}

# wait_enforced: the policy takes a few seconds; wait until the stranger is blocked (or give up)
wait_enforced() {
  local i
  for i in $(seq 1 10); do
    reach moon-ext-b web-client || return 0
    sleep 3
  done
}
