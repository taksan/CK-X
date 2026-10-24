#!/bin/bash

# Setup for CKS-004 Question 8: extend a base audit policy. Namespace frontend (the PVC rule) and
# audit-other (a namespace where PVC changes must NOT be logged) are exclusive to this question.
#
# The base policy only says what NOT to log, and ends with a catch-all "level: None": rules appended
# after it never match, the new rules must come before it. The nodes were restored to the checkpoint
# by the pre-setup hook, so /etc/audit has no policy yet.

source "$(dirname "$0")/../lib/wait-cluster.sh"

ensure_namespace frontend
ensure_namespace audit-other

ssh -o StrictHostKeyChecking=no k8s-api-server 'bash -s' <<'EOF'
mkdir -p /etc/audit
cat > /etc/audit/audit-policy.yaml <<'POLICY'
apiVersion: audit.k8s.io/v1
kind: Policy
rules:
  # do not log the kube-proxy watches of endpoints and services
  - level: None
    users: ["system:kube-proxy"]
    verbs: ["watch"]
    resources:
      - group: ""
        resources: ["endpoints", "services", "services/status"]
  # do not log health checks and version requests
  - level: None
    nonResourceURLs:
      - "/healthz*"
      - "/version"
      - "/readyz*"
      - "/livez*"
  # do not log anything else
  - level: None
POLICY
EOF

echo "Setup completed for CKS-004 Question 8 (base policy in /etc/audit/audit-policy.yaml on k8s-api-server)"
exit 0
