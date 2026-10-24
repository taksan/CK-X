#!/bin/bash

# Setup for MHAGOU-007 Question 9: a Falco rule for reads of /dev/mem from a container.
# Namespace devmem-lab is exclusive: Pod test-falco (busybox, no /dev/mem) on node01. The candidate edits
# /etc/falco/falco_rules.local.yaml on node01 (tracked by the node checkpoint).

source "$(dirname "$0")/../lib/wait-cluster.sh"
source "$(dirname "$0")/../lib/nodes.sh"

NS="devmem-lab"
ensure_namespace "$NS"
kubectl delete pod test-falco -n "$NS" --ignore-not-found --now >/dev/null 2>&1

kubectl apply -f - >/dev/null <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: test-falco
  namespace: ${NS}
spec:
  nodeName: ${NODE01}
  containers:
  - name: test
    image: busybox:1.36.1
    command: ["sleep", "86400"]
EOF

kubectl wait --for=condition=Ready pod/test-falco -n "$NS" --timeout=180s >/dev/null || { echo "WARNING: test-falco is not ready"; exit 1; }

echo "Setup completed for MHAGOU-007 Question 9 (namespace '$NS', Pod test-falco on $NODE01)"
exit 0
