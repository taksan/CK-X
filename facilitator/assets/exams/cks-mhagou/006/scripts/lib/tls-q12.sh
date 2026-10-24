#!/bin/bash
# Source this file: helpers of question 12 (manifest flags are read on the control plane)

source "$(dirname "${BASH_SOURCE[0]}")/nodes.sh"

CP="$CONTROL_PLANE"
CIPHER="TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256"

manifest_cmd() { # kube-apiserver | etcd -> JSON array of the command
  ssh -o StrictHostKeyChecking=no "$CP" "yq -o=json '.spec.containers[0].command' /etc/kubernetes/manifests/$1.yaml" 2>/dev/null
}

running_cmd() { # process name -> its command line
  ssh -o StrictHostKeyChecking=no "$CP" "pgrep -a $1" 2>/dev/null
}

api_address() {
  kubectl get node "$CP" -o jsonpath='{.status.addresses[?(@.type=="InternalIP")].address}' 2>/dev/null
}

# tls_accepts VERSION (tls1_2|tls1_3): 0 when the API server completes a handshake with that version
tls_accepts() {
  local ip; ip=$(api_address)
  openssl s_client -connect "$ip:6443" -"$1" </dev/null 2>&1 | grep -Eq "New, TLSv1\.[23], Cipher is [A-Za-z0-9_-]+" && return 0
  return 1
}
