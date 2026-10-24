#!/bin/bash

# Runs on the jumphost after the assets are extracted and BEFORE the jumphost
# waits for the API server and runs the question setups.
#
# For a kubeadm cluster it puts the nodes back to the checkpoint taken on the
# first run, so every exam starts from a clean slate even if the previous
# candidate left the control plane broken. Skipped on clusters without kubeadm
# static pods (e.g. k3d).

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] [pre-setup] $*"; }

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if ! ssh -o BatchMode=yes -o ConnectTimeout=10 k8s-api-server 'test -d /etc/kubernetes/manifests' >/dev/null 2>&1; then
  log "No kubeadm control plane reachable over ssh: skipping node checkpoint"
  exit 0
fi

"$HERE/lib/node-checkpoint.sh" restore || { log "node checkpoint restore failed"; exit 1; }

export KUBECONFIG="${KUBECONFIG:-/home/candidate/.kube/kubeconfig}"
source "$HERE/lib/wait-cluster.sh"

log "Waiting for the API server, the nodes and the controllers to be ready"
wait_cluster_ready
log "Cluster is ready"
exit 0
