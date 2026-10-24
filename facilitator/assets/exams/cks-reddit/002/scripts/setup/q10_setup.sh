#!/bin/bash

# Setup for CKS-002 Question 10: kube-bench findings (kubelet on node01, etcd)
#
# The nodes were restored to the checkpoint by the pre-setup hook. This script
# breaks the kubelet configuration of node01 (anonymous auth on, AlwaysAllow
# authorization, read-only port 10255), enables etcd auto-tls and disables
# service account lookup on the API server. --profiling=false, also asked by the
# question, is simply absent from a kubeadm default manifest.

set -euo pipefail

source "$(dirname "$0")/../lib/wait-cluster.sh"
source "$(dirname "$0")/../lib/nodes.sh"

# kubelet on node01
ssh -o StrictHostKeyChecking=no node01 'bash -s' <<'EOF'
set -euo pipefail
CFG=/var/lib/kubelet/config.yaml
sed -i '/^  anonymous:/{n;s/enabled: false/enabled: true/}' $CFG
sed -i 's/^  mode: Webhook/  mode: AlwaysAllow/' $CFG
sed -i '/^readOnlyPort:/d' $CFG
echo 'readOnlyPort: 10255' >> $CFG
systemctl restart kubelet
EOF

# etcd and API server on the control plane
ssh -o StrictHostKeyChecking=no k8s-api-server 'bash -s' <<'EOF'
set -euo pipefail
MANIFEST=/etc/kubernetes/manifests/etcd.yaml
grep -q -- '--auto-tls=true' $MANIFEST || sed -i '/- --advertise-client-urls=/a\    - --auto-tls=true\n    - --peer-auto-tls=true' $MANIFEST

APISERVER=/etc/kubernetes/manifests/kube-apiserver.yaml
grep -q -- '--service-account-lookup=false' $APISERVER || sed -i '/- --allow-privileged=true/a\    - --service-account-lookup=false' $APISERVER
EOF

echo "Waiting for etcd and the API server to restart..."
for i in $(seq 1 60); do
  CMD=$(kubectl get pods -n kube-system -l component=etcd -o jsonpath='{.items[0].spec.containers[0].command}' 2>/dev/null || true)
  API=$(kubectl get pods -n kube-system -l component=kube-apiserver -o jsonpath='{.items[0].spec.containers[0].command}' 2>/dev/null || true)
  if echo "$CMD" | grep -q -- '--auto-tls=true' && echo "$API" | grep -q -- '--service-account-lookup=false' \
     && kubectl get --raw /readyz >/dev/null 2>&1; then
    break
  fi
  sleep 5
done

wait_cluster_ready

kubectl wait --for=condition=Ready node/$NODE01 --timeout=180s

echo "Setup completed for CKS-002 Question 10 (insecure kubelet, etcd and API server settings applied)"
exit 0
