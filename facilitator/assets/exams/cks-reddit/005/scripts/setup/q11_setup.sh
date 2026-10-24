#!/bin/bash

# Setup for CKS-005 Question 11: seccompDefault in the kubelet of node02.
# Namespace kubelet-lab is exclusive. The candidate edits /var/lib/kubelet/config.yaml of node02,
# restarts the kubelet and creates the Pod "probe" on node02 to show the effect. The node restore
# puts the kubelet config back.

source "$(dirname "$0")/../lib/wait-cluster.sh"

ensure_namespace kubelet-lab
kubectl delete pod probe -n kubelet-lab --ignore-not-found --now >/dev/null 2>&1

echo "Setup completed for CKS-005 Question 11 (namespace kubelet-lab)"
exit 0
