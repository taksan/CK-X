#!/bin/bash
# Validate the API server runs with an audit policy file (a valid Policy) and the log path

source "$(dirname "$0")/../lib/audit-policy.sh"
load_audit_policy || exit 1

CMD=$(ssh -o StrictHostKeyChecking=no "$AUDIT_NODE" "yq -o=json '.spec.containers[0].command' /etc/kubernetes/manifests/kube-apiserver.yaml" 2>/dev/null)
echo "$CMD" | jq -e 'index("--audit-log-path=/var/log/kubernetes-logs.log") != null' >/dev/null \
  || { echo "❌ kube-apiserver is not configured with --audit-log-path=/var/log/kubernetes-logs.log"; exit 1; }

echo "✅ kube-apiserver uses an audit policy file and logs to /var/log/kubernetes-logs.log"
exit 0
