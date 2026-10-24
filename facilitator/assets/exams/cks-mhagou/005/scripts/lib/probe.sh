#!/bin/bash
# Source this file in the validators that test network traffic between Pods.
#
#   pod_ip NS POD                      IP address of a Pod
#   reach NS POD IP PORT               0 when POD can open an HTTP connection to IP:PORT (wget, 3 s)
#   wait_blocked NS POD IP PORT        polls up to 18 s until the connection is refused/blocked (the
#                                      policy needs a few seconds to be enforced); returns 0 when blocked

pod_ip() {
  kubectl get pod "$2" -n "$1" -o jsonpath='{.status.podIP}' 2>/dev/null
}

reach() {
  kubectl exec -n "$1" "$2" -- wget -q -T 3 -O /dev/null "http://$3:$4/" >/dev/null 2>&1
}

wait_blocked() {
  local i
  for i in $(seq 1 6); do
    reach "$1" "$2" "$3" "$4" || return 0
    sleep 3
  done
  return 1
}
