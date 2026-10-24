#!/bin/bash
# Validate the API server runs with the audit policy /etc/kubernetes/audit/policy.yaml (a valid
# Policy) and writes the log to /etc/kubernetes/audit/logs/audit.log

source "$(dirname "$0")/../lib/audit-policy.sh"
load_audit_policy || exit 1

CMD=$(ssh -o StrictHostKeyChecking=no "$AUDIT_NODE" "yq -o=json '.spec.containers[0].command' /etc/kubernetes/manifests/kube-apiserver.yaml" 2>/dev/null)
[ -n "$CMD" ] || { echo "❌ Unable to read the kube-apiserver manifest on the control plane"; exit 1; }

echo "$CMD" | jq -e 'index("--audit-policy-file=/etc/kubernetes/audit/policy.yaml") != null' >/dev/null \
  || { echo "❌ kube-apiserver is not configured with --audit-policy-file=/etc/kubernetes/audit/policy.yaml"; exit 1; }
echo "$CMD" | jq -e 'index("--audit-log-path=/etc/kubernetes/audit/logs/audit.log") != null' >/dev/null \
  || { echo "❌ kube-apiserver is not configured with --audit-log-path=/etc/kubernetes/audit/logs/audit.log"; exit 1; }

echo "✅ kube-apiserver uses /etc/kubernetes/audit/policy.yaml and logs to /etc/kubernetes/audit/logs/audit.log"
exit 0
