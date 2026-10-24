#!/bin/bash

# Setup for CKS-003 Question 11: CIS / kube-bench findings
#
# The nodes were restored to the checkpoint by the pre-setup hook. This script breaks:
#   - the kubelet of node02: anonymous auth on, AlwaysAllow authorization, read-only port 10255
#   - etcd: client certificate authentication off and auto-tls on
# --profiling=false of the controller-manager and the scheduler is simply absent from a
# kubeadm default manifest. (The API server is not touched: AlwaysAllow there makes it answer
# 401 to the kubelet probes and kills it in a loop.)

set -euo pipefail

source "$(dirname "$0")/../lib/wait-cluster.sh"
source "$(dirname "$0")/../lib/nodes.sh"

ssh -o StrictHostKeyChecking=no node02 'bash -s' <<'EOF'
set -euo pipefail
CFG=/var/lib/kubelet/config.yaml
sed -i '/^  anonymous:/{n;s/enabled: false/enabled: true/}' $CFG
sed -i 's/^  mode: Webhook/  mode: AlwaysAllow/' $CFG
sed -i '/^readOnlyPort:/d' $CFG
echo 'readOnlyPort: 10255' >> $CFG
systemctl restart kubelet
EOF

ssh -o StrictHostKeyChecking=no k8s-api-server 'bash -s' <<'EOF'
set -euo pipefail
MANIFEST=/etc/kubernetes/manifests/etcd.yaml
sed -i 's/--client-cert-auth=true/--client-cert-auth=false/' $MANIFEST
grep -q -- '--auto-tls=true' $MANIFEST || sed -i '/- --advertise-client-urls=/a\    - --auto-tls=true' $MANIFEST
EOF

echo "Waiting for etcd to restart..."
for i in $(seq 1 60); do
  CMD=$(kubectl get pods -n kube-system -l component=etcd -o jsonpath='{.items[0].spec.containers[0].command}' 2>/dev/null || true)
  if echo "$CMD" | grep -q -- '--auto-tls=true' && kubectl get --raw /readyz >/dev/null 2>&1; then
    break
  fi
  sleep 5
done

wait_cluster_ready
kubectl wait --for=condition=Ready node/$NODE02 --timeout=180s

echo "Setup completed for CKS-003 Question 11 (insecure kubelet of $NODE02 and etcd settings applied)"
exit 0
