#!/bin/bash

# Setup for MHagou-003 Question 1: disable anonymous authentication of the kube-apiserver.
# Node level question (no namespace). The nodes were restored to the checkpoint by the pre-setup
# hook, so the manifest has no --anonymous-auth flag (anonymous requests are authenticated as
# system:anonymous and answered with 403 or 200). Nothing has to be prepared; this script only
# makes sure the starting point is what the question expects.

source "$(dirname "$0")/../lib/wait-cluster.sh"
source "$(dirname "$0")/../lib/nodes.sh"

CMD=$(ssh -o StrictHostKeyChecking=no k8s-api-server "yq -o=json '.spec.containers[0].command' /etc/kubernetes/manifests/kube-apiserver.yaml" 2>/dev/null)
if echo "$CMD" | jq -e 'any(.[]; . == "--anonymous-auth=false")' >/dev/null 2>&1; then
  echo "WARNING: the kube-apiserver already runs with --anonymous-auth=false (node restore did not run?)"
  exit 1
fi

echo "Setup completed for MHagou-003 Question 1 (kube-apiserver on ${CONTROL_PLANE})"
exit 0
