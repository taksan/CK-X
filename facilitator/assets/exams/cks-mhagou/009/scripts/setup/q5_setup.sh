#!/bin/bash

# Setup for MHagou CKS exam 9, Question 5: audit logging with an extended policy.
# Namespace frontend is exclusive. The base policy /etc/kubernetes/logpolicy/audit-policy.yaml only
# says what NOT to log; the API server has no audit flags. The node restore removes the file.

source "$(dirname "$0")/../lib/wait-cluster.sh"
source "$(dirname "$0")/../lib/audit-reset.sh"

reset_apiserver_audit || exit 1

ensure_namespace frontend

ssh -o StrictHostKeyChecking=no k8s-api-server 'bash -s' <<'EOF'
mkdir -p /etc/kubernetes/logpolicy
cat > /etc/kubernetes/logpolicy/audit-policy.yaml <<'POLICY'
apiVersion: audit.k8s.io/v1
kind: Policy
omitStages:
  - "RequestReceived"
rules:
  # do not log health checks and version requests
  - level: None
    nonResourceURLs:
      - "/healthz*"
      - "/readyz*"
      - "/livez*"
      - "/version"
  # do not log the kube-proxy watches of endpoints and services
  - level: None
    users: ["system:kube-proxy"]
    verbs: ["watch"]
    resources:
      - group: ""
        resources: ["endpoints", "services", "services/status"]
POLICY
EOF

echo "Setup completed for MHagou exam 9 Question 5 (base policy in /etc/kubernetes/logpolicy/audit-policy.yaml on k8s-api-server)"
exit 0
