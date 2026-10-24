#!/bin/bash

# Setup for MHagou-006 Question 12: TLS hardening of the control plane (kube-apiserver and etcd).
# kubeadm etcd listens on https only, so the setup adds an extra plain-HTTP client listener
# (http://127.0.0.1:2399, nothing uses it) that the candidate has to remove. The manifest is tracked by
# the node checkpoint and put back by the restore.

source "$(dirname "$0")/../lib/wait-cluster.sh"

ssh -o StrictHostKeyChecking=no k8s-api-server 'bash -s' <<'EOF'
set -e
yq -i '(.spec.containers[0].command[] | select(test("^--listen-client-urls="))) |= . + ",http://127.0.0.1:2399"' /etc/kubernetes/manifests/etcd.yaml
for i in $(seq 1 60); do ss -ltn | grep -q ':2399 ' && break; sleep 2; done
ss -ltn | grep -q ':2399 '
EOF
[ $? -eq 0 ] || { echo "Failed to prepare etcd"; exit 1; }

wait_cluster_ready 120
echo "Setup completed for MHagou-006 Question 12 (etcd has an extra plain-HTTP client listener)"
exit 0
