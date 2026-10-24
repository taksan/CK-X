#!/bin/bash

# Setup for CKS-002 Question 8: API server re-hardening
#
# Starts from an insecure API server: no NodeRestriction admission plugin and a
# ClusterRoleBinding that gives system:anonymous cluster-admin. The nodes were
# restored to the checkpoint by the pre-setup hook, so the manifest is pristine
# at this point.
#
# The authorization mode is deliberately left as Node,RBAC: with AlwaysAllow the
# API server answers 401 to anonymous requests, so kubelet's unauthenticated
# startup/liveness probes fail and the API server is killed in a loop. For the
# same reason the question does not ask to disable anonymous authentication
# (--anonymous-auth=false): the probes of the kubeadm manifest are anonymous and
# the API server would never become ready.

set -euo pipefail

source "$(dirname "$0")/../lib/wait-cluster.sh"

MANIFEST="/etc/kubernetes/manifests/kube-apiserver.yaml"

ssh -o StrictHostKeyChecking=no k8s-api-server 'bash -s' <<EOF
set -euo pipefail
sed -i '/--enable-admission-plugins=NodeRestriction/d' $MANIFEST
EOF

echo "Waiting for the API server to restart with the insecure configuration..."
for i in $(seq 1 60); do
  CMD=$(kubectl get pods -n kube-system -l component=kube-apiserver -o jsonpath='{.items[0].spec.containers[0].command}' 2>/dev/null || true)
  if ! echo "$CMD" | grep -q -- 'NodeRestriction' && kubectl get --raw /readyz >/dev/null 2>&1; then
    break
  fi
  sleep 5
done

wait_cluster_ready

kubectl create clusterrolebinding anonymous-admin --clusterrole=cluster-admin --user=system:anonymous \
  --dry-run=client -o yaml | kubectl apply -f -

echo "Setup completed for CKS-002 Question 8 (insecure API server configuration applied)"
exit 0
