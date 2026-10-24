#!/bin/bash

# Setup for MHagou CKS exam 9, Question 12: secure the API server authentication and authorization.
#
# Starts from an insecure API server: no NodeRestriction (the flag --enable-admission-plugins is
# removed), anonymous authentication open (the default) and a ClusterRoleBinding system:anonymous that
# gives system:anonymous cluster-admin. The authorization mode is deliberately left as Node,RBAC:
# with AlwaysAllow the API server answers 401 to anonymous requests, kubelet's unauthenticated probes
# fail and the API server is killed in a loop. For the same reason the plain flag
# --anonymous-auth=false cannot be the answer (the kubelet probes /livez and /readyz without
# credentials): the structured AuthenticationConfiguration keeps those endpoints anonymous.
# The nodes were restored by the pre-setup hook.

set -euo pipefail

source "$(dirname "$0")/../lib/wait-cluster.sh"

MANIFEST="/etc/kubernetes/manifests/kube-apiserver.yaml"

ssh -o StrictHostKeyChecking=no k8s-api-server 'bash -s' <<EOF
set -euo pipefail
sed -i '/--enable-admission-plugins=/d' $MANIFEST
EOF

echo "Waiting for the API server to restart with the insecure configuration..."
sleep 20
for i in $(seq 1 60); do
  CMD=$(kubectl get pods -n kube-system -l component=kube-apiserver -o jsonpath='{.items[0].spec.containers[0].command}' 2>/dev/null || true)
  if [ -n "$CMD" ] && ! echo "$CMD" | grep -q -- '--enable-admission-plugins' && kubectl get --raw /readyz >/dev/null 2>&1; then
    break
  fi
  sleep 5
done

wait_cluster_ready

kubectl create clusterrolebinding system:anonymous --clusterrole=cluster-admin --user=system:anonymous \
  --dry-run=client -o yaml | kubectl apply -f -

echo "Setup completed for MHagou exam 9 Question 12 (insecure API server configuration applied)"
exit 0
