#!/bin/bash
# Source this file (question 13): dry-run Pod creation helpers
#   try_pod NAMESPACE IMAGE   prints the API answer of a server-side dry-run of a Pod with that image
#   denied OUTPUT             succeeds when the answer is a policy denial
try_pod() {
  kubectl run "ckx-gate-$RANDOM" --image="$2" --restart=Never -n "$1" --dry-run=server 2>&1
}
denied() { echo "$1" | grep -qiE 'denied request|forbidden|ValidatingAdmissionPolicy'; }
