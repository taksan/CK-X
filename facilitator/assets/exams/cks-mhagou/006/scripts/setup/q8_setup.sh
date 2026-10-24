#!/bin/bash

# Setup for MHagou-006 Question 8: an insecure kubelet on the control plane node.
# kubeadm configures the kubelet securely, so the setup weakens the kubelet config of k8s-api-server
# (anonymous authentication on, AlwaysAllow authorization, read-only port 10255) and restarts it.
# /var/lib/kubelet/config.yaml is tracked by the node checkpoint: the restore puts it back and
# restarts the kubelet.

source "$(dirname "$0")/../lib/nodes.sh"

source "$(dirname "$0")/../lib/wait-cluster.sh"

ssh -o StrictHostKeyChecking=no k8s-api-server 'bash -s' <<'EOF'
set -e
yq -i '.authentication.anonymous.enabled = true | .authorization.mode = "AlwaysAllow" | .readOnlyPort = 10255' /var/lib/kubelet/config.yaml
systemctl restart kubelet
for i in $(seq 1 30); do ss -ltn | grep -q ':10255 ' && break; sleep 2; done
ss -ltn | grep -q ':10255 '
EOF
[ $? -eq 0 ] || { echo "Failed to prepare the kubelet of the control plane"; exit 1; }

wait_cluster_ready
echo "Setup completed for MHagou-006 Question 8 (kubelet of ${CONTROL_PLANE} is insecure)"
exit 0
