#!/bin/bash

# Setup for MHagou-006 Question 13: a CiliumNetworkPolicy for egress. Namespaces app, data and manage
# are exclusive to this question; each holds one nginx Pod (app1, data1, manage1) labelled id=<ns>.

source "$(dirname "$0")/../lib/wait-cluster.sh"

for ns in app data manage; do
  ensure_namespace "$ns"
  kubectl delete ciliumnetworkpolicies.cilium.io --all -n "$ns" >/dev/null 2>&1
  kubectl delete networkpolicies --all -n "$ns" >/dev/null 2>&1
  kubectl delete pod "${ns}1" -n "$ns" --ignore-not-found --now >/dev/null 2>&1
  kubectl apply -f - >/dev/null <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: ${ns}1
  namespace: ${ns}
  labels: {id: ${ns}}
spec:
  containers:
  - {name: web, image: "nginx:1.27-alpine"}
EOF
done

echo "Setup completed for MHagou-006 Question 13 (namespaces app, data, manage)"
exit 0
