#!/bin/bash

# Setup for MHagou-006 Question 9: a client certificate for the user 60099@internal.users.
# Namespace staff-lab is exclusive and empty. The candidate adds credentials and a context to the
# kubeconfig of the jumphost and a CertificateSigningRequest to the cluster (both are removed by the
# session cleanup).

source "$(dirname "$0")/../lib/wait-cluster.sh"

ensure_namespace staff-lab
for csr in $(kubectl get csr -o name 2>/dev/null); do
  if kubectl get "$csr" -o jsonpath='{.spec.request}' 2>/dev/null | base64 -d 2>/dev/null | openssl req -noout -subject 2>/dev/null | grep -q '60099@internal.users'; then
    kubectl delete "$csr" --ignore-not-found >/dev/null 2>&1
  fi
done

echo "Setup completed for MHagou-006 Question 9 (namespace staff-lab)"
exit 0
