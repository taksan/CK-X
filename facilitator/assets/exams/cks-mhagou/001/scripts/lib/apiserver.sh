#!/bin/bash
# Source this file in validators that look at the kube-apiserver.
#
#   apiserver_command_json      the "command" array of the kube-apiserver static pod manifest, read on the
#                               control plane (the mirror Pod in the API can lag behind or be missing)
#   apiserver_flag NAME         value of --NAME=value (empty when the flag is absent)
#   apiserver_manifest_volumes  the volumes/volumeMounts of the manifest as JSON {"mounts": [...], "volumes": [...]}
#   wait_api_ready [SECONDS]    wait until the API answers /readyz (default 120 s); returns 1 on timeout

APISERVER_NODE="${APISERVER_NODE:-k8s-api-server}"
APISERVER_MANIFEST=/etc/kubernetes/manifests/kube-apiserver.yaml

apiserver_command_json() {
  ssh -o StrictHostKeyChecking=no "$APISERVER_NODE" "yq -o=json '.spec.containers[0].command' $APISERVER_MANIFEST" 2>/dev/null
}

apiserver_flag() {
  apiserver_command_json | jq -r --arg p "--$1=" '[.[]? | select(startswith($p))][0] // empty | sub($p; "")' 2>/dev/null
}

apiserver_manifest_volumes() {
  ssh -o StrictHostKeyChecking=no "$APISERVER_NODE" "yq -o=json '{\"mounts\": .spec.containers[0].volumeMounts, \"volumes\": .spec.volumes}' $APISERVER_MANIFEST" 2>/dev/null
}

wait_api_ready() {
  local i max=$(( ${1:-120} / 4 ))
  for i in $(seq 1 "$max"); do
    kubectl get --raw /readyz >/dev/null 2>&1 && return 0
    sleep 4
  done
  return 1
}
