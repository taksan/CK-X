#!/bin/bash

# Setup for MHAGOU-007 Question 3: kubelet of node02 with anonymous access and no authorization.
# The kubelet configuration of node02 is changed (the node restore puts it back from the checkpoint).

source "$(dirname "$0")/../lib/wait-cluster.sh"
source "$(dirname "$0")/../lib/nodes.sh"

ssh -o StrictHostKeyChecking=no node02 'bash -s' <<'EOF'
set -e
CFG=/var/lib/kubelet/config.yaml
yq -i '.authentication.anonymous.enabled = true | .authorization.mode = "AlwaysAllow"' "$CFG"
systemctl restart kubelet
EOF

for i in $(seq 1 40); do
  [ "$(kubectl get node "$NODE02" -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null)" = "True" ] && break
  sleep 3
done

echo "Setup completed for MHAGOU-007 Question 3 (kubelet of $NODE02: anonymous auth on, authorization AlwaysAllow)"
exit 0
