#!/bin/bash

# Setup for MHAGOU-002 Question 7: kube-bench findings on the worker node01.
# The nodes were restored to the checkpoint by the pre-setup hook. This script breaks the kubelet
# of node01 (config restored from the checkpoint at the end): authorization mode AlwaysAllow,
# protectKernelDefaults false and the read-only port 10255. No namespace: node-level question.
# The sysctls that protectKernelDefaults demands are already set on the nodes.

set -euo pipefail

source "$(dirname "$0")/../lib/wait-cluster.sh"
source "$(dirname "$0")/../lib/nodes.sh"

ssh -o StrictHostKeyChecking=no node01 'bash -s' <<'EOF'
set -euo pipefail
CFG=/var/lib/kubelet/config.yaml
sed -i 's/^  mode: Webhook/  mode: AlwaysAllow/' $CFG
sed -i '/^protectKernelDefaults:/d' $CFG
echo 'protectKernelDefaults: false' >> $CFG
sed -i '/^readOnlyPort:/d' $CFG
echo 'readOnlyPort: 10255' >> $CFG
systemctl restart kubelet
EOF

for i in $(seq 1 60); do
  MODE=$(kubectl get --raw "/api/v1/nodes/${NODE01}/proxy/configz" 2>/dev/null | jq -r '.kubeletconfig.authorization.mode' 2>/dev/null || true)
  [ "$MODE" = "AlwaysAllow" ] && break
  sleep 3
done
kubectl wait --for=condition=Ready node/${NODE01} --timeout=180s >/dev/null

echo "Setup completed for MHAGOU-002 Question 7 (insecure kubelet configuration on ${NODE01})"
exit 0
