#!/bin/bash

# Setup for MHagou-004 Question 4: a Falco message for shells opened in containers.
# Namespace shell-watch is exclusive to this question. Falco runs as a systemd service on the nodes;
# the question is about the second worker node, where the practice Pod runs. The Pod only runs a process that exists
# in the image (sleep); the candidate (and the validator) exec into it.

source "$(dirname "$0")/../lib/wait-cluster.sh"
source "$(dirname "$0")/../lib/nodes.sh"

NS="shell-watch"
ensure_namespace "$NS"
kubectl delete pod shell-practice -n "$NS" --ignore-not-found --now >/dev/null 2>&1

kubectl apply -f - >/dev/null <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: shell-practice
  namespace: ${NS}
spec:
  nodeName: $NODE02
  terminationGracePeriodSeconds: 0
  containers:
  - name: practice
    image: busybox:1.36.1
    command: ["sleep", "86400"]
EOF

echo "Setup completed for MHagou-004 Question 4 (namespace '$NS', Pod shell-practice on $NODE02)"
exit 0
