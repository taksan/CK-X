#!/bin/bash
# Helpers of the validators of question 1 (source with: source "$(dirname "$0")/../lib/q1-lib.sh").
# Sets the addresses of the fixture Pods and offers: expect_ok / expect_blocked

source "$(dirname "$0")/../lib/probe.sh"

NS="network-security"
PEER="network-security-peer"

init_q1() {
  IP_BA=$(pod_ip "$NS" backend-a); IP_BB=$(pod_ip "$NS" backend-b)
  IP_DB=$(pod_ip "$NS" database); IP_FR=$(pod_ip "$NS" frontend); IP_OT=$(pod_ip "$NS" other)
  IP_PDB=$(pod_ip "$PEER" database)
  for v in "$IP_BA" "$IP_BB" "$IP_DB" "$IP_FR" "$IP_OT" "$IP_PDB"; do
    if [ -z "$v" ]; then
      echo "❌ A fixture Pod of the exercise is missing or has no address (the existing Pods must not be deleted or recreated)"
      return 1
    fi
  done
}

# expect_ok DESCRIPTION NS POD IP PORT
expect_ok() {
  reach "$2" "$3" "$4" "$5" || { echo "❌ $1: $2/$3 cannot connect to $4:$5 but it must be allowed"; return 1; }
}

# expect_blocked DESCRIPTION NS POD IP PORT
# The first denied probe of a validator polls (a policy needs a few seconds to be enforced, up to 18 s);
# the following probes are checked once, so a missing policy does not cost 45 s per probe.
_POLLED=0
expect_blocked() {
  if [ "$_POLLED" = 0 ]; then
    _POLLED=1
    wait_blocked "$2" "$3" "$4" "$5" && return 0
  else
    reach "$2" "$3" "$4" "$5" || return 0
  fi
  echo "❌ $1: $2/$3 can still connect to $4:$5 but it must be denied"
  return 1
}
