#!/bin/bash
# Source this file (question 8).
#   ns_create_probe NAME [LABELS_YAML]  server-side dry-run creation of a namespace, prints the output
#   ns_rejected                         reads an output on stdin: success only for a real rejection (an error from
#                                       the server), not for a warning that mentions the policy
#   ns_denied_probe                     polls until a namespace lab-... without label is rejected (up to 45 s)

ns_create_probe() {
  local name="$1" labels="$2"
  {
    echo "apiVersion: v1"
    echo "kind: Namespace"
    echo "metadata:"
    echo "  name: $name"
    [ -n "$labels" ] && printf '  labels:\n%s\n' "$labels"
  } | kubectl create --dry-run=server -f - 2>&1
}

ns_rejected() {
  grep -qE '^Error from server|denied request|is forbidden'
}

ns_denied_probe() {
  local out i
  for i in $(seq 1 15); do
    out=$(ns_create_probe "lab-ckx$RANDOM$RANDOM")
    echo "$out" | ns_rejected && return 0
    sleep 3
  done
  return 1
}
