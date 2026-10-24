#!/bin/bash
# Source this file in the setup of a question that asks the candidate to ENABLE audit logging.
#
#   reset_apiserver_audit    removes the --audit-* flags from the kube-apiserver manifest when the cluster
#                            already has them (a cluster of the user may have auditing configured), so that
#                            the question starts from an API server without auditing; waits for the restart.
#
# Nothing has to be put back by hand: the node checkpoint covers /etc/kubernetes, so the restore at the
# start of the next exam (and in the session cleanup) brings the original manifest back.

AUDIT_RESET_NODE="${AUDIT_RESET_NODE:-k8s-api-server}"

reset_apiserver_audit() {
  local manifest=/etc/kubernetes/manifests/kube-apiserver.yaml i
  if ! ssh -o StrictHostKeyChecking=no "$AUDIT_RESET_NODE" \
        "yq -e '.spec.containers[0].command[] | select(test(\"^--audit-\"))' $manifest" >/dev/null 2>&1; then
    return 0   # no audit flags: nothing to do
  fi
  echo "The API server has audit flags: removing them for this question (the session cleanup restores them)"
  ssh -o StrictHostKeyChecking=no "$AUDIT_RESET_NODE" \
    "yq -i 'del(.spec.containers[0].command[] | select(test(\"^--audit-\")))' $manifest" || return 1
  # wait until the running kube-apiserver no longer has the flags (the kubelet recreates the static pod)
  for i in $(seq 1 60); do
    ssh -o StrictHostKeyChecking=no "$AUDIT_RESET_NODE" \
      "pgrep -af '[k]ube-apiserver' | grep -q . && ! pgrep -af '[k]ube-apiserver' | grep -q -- '[-]-audit-'" 2>/dev/null && break
    sleep 3
  done
  for i in $(seq 1 60); do
    kubectl get --raw /readyz >/dev/null 2>&1 && return 0
    sleep 4
  done
  echo "WARNING: the API server did not become ready after removing the audit flags"
  return 1
}
