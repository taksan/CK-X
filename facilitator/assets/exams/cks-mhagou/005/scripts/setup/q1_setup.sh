#!/bin/bash

# Setup for MHagou-005 Question 1: NetworkPolicies for the backend Pods.
# Namespaces network-security and network-security-peer are exclusive to this question. Every Pod
# serves HTTP on 8080, 8081, 5432 and 5433 (busybox httpd), so a connection to any of these ports
# works until the candidate's policies are in place.

source "$(dirname "$0")/../lib/wait-cluster.sh"

DIR="/tmp/exam/mhagou-005-q1"
for ns in network-security network-security-peer; do
  ensure_namespace "$ns"
  kubectl delete networkpolicy --all -n "$ns" >/dev/null 2>&1
done

create_pod() { # namespace name role
  kubectl apply -f - >/dev/null <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: $2
  namespace: $1
  labels:
    app: $3
spec:
  automountServiceAccountToken: false
  containers:
  - name: fixture
    image: busybox:1.36.1
    command:
    - sh
    - -ec
    - |
      mkdir -p /tmp/www
      echo mhagou-network-fixture > /tmp/www/index.html
      for port in 8080 8081 5432 5433; do
        httpd -p "\$port" -h /tmp/www
      done
      exec sleep 2147483647
    readinessProbe:
      exec:
        command: [sh, -ec, 'wget -q -T 2 -O /dev/null http://127.0.0.1:8080/']
      initialDelaySeconds: 1
      periodSeconds: 2
EOF
}

for spec in 'backend-a backend' 'backend-b backend' 'frontend frontend' 'database database' 'other other'; do
  read -r name role <<< "$spec"
  kubectl delete pod "$name" -n network-security --ignore-not-found --now >/dev/null 2>&1
  create_pod network-security "$name" "$role"
done
for spec in 'frontend frontend' 'database database'; do
  read -r name role <<< "$spec"
  kubectl delete pod "$name" -n network-security-peer --ignore-not-found --now >/dev/null 2>&1
  create_pod network-security-peer "$name" "$role"
done

for ns in network-security network-security-peer; do
  kubectl wait -n "$ns" --for=condition=Ready pod --all --timeout=180s >/dev/null 2>&1 || { echo "WARNING: the Pods of $ns are not ready"; exit 1; }
done

# the identity of the fixtures (the task forbids recreating them)
mkdir -p "${DIR:?}"
rm -f "${DIR:?}"/.uids
for ns in network-security network-security-peer; do
  kubectl get pods -n "$ns" -o jsonpath='{range .items[*]}{.metadata.namespace}/{.metadata.name}={.metadata.uid}{"\n"}{end}' >> "$DIR/.uids"
done

echo "Setup completed for MHagou-005 Question 1 (namespaces network-security and network-security-peer)"
exit 0
