#!/bin/bash
# Source this file. Question 11 helpers: server-side dry-run of Pods against the admission policy.
#
#   probe_pod NAMESPACE NAME 'SPEC-YAML-LINES'   prints the API answer; the SPEC lines are indented under "spec:"
#   denied OUTPUT                                true when the answer is a policy denial

probe_pod() {
  local ns="$1" name="$2" spec="$3"
  cat <<EOF | kubectl create -n "$ns" --dry-run=server -f - 2>&1
apiVersion: v1
kind: Pod
metadata: {name: $name}
spec:
$spec
EOF
}

# a real rejection (not the "Warning: ..." lines that the Warn/Audit actions produce)
denied() { echo "$1" | grep -v '^Warning:' | grep -qiE 'denied request|forbidden'; }
