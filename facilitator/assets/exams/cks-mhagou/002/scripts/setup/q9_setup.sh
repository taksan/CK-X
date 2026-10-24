#!/bin/bash

# Setup for MHAGOU-002 Question 9: change the output of a Falco rule. Namespace space is exclusive.
# The Pod worker-pod runs on node02 (where the Falco service reads the rules from /etc/falco).
# The local rules file of node02 is emptied here so that no earlier local rule can match the same
# event first (Falco: rule_matching first). /etc/falco is restored by the node checkpoint restore,
# and the Falco service is restarted then if the rules changed.

source "$(dirname "$0")/../lib/wait-cluster.sh"
source "$(dirname "$0")/../lib/nodes.sh"

NS="space"

ssh -o StrictHostKeyChecking=no node02 'printf "# Local rule customizations\n" > /etc/falco/falco_rules.local.yaml'

ensure_namespace "$NS"
kubectl delete pod worker-pod -n "$NS" --ignore-not-found --now >/dev/null 2>&1

kubectl apply -f - >/dev/null <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: worker-pod
  namespace: ${NS}
spec:
  nodeName: ${NODE02}
  containers:
  - name: main
    image: busybox:1.36.1
    command: ["sleep", "86400"]
EOF

echo "Setup completed for MHAGOU-002 Question 9 (namespace '$NS', Falco of ${NODE02})"
exit 0
