#!/bin/bash
# kube-apiserver uses /etc/kubernetes/test-audit.yaml (a valid audit Policy) as its audit policy

source "$(dirname "$0")/../lib/nodes.sh"
NODE="${CONTROL_PLANE}"
CMD=$(ssh -o StrictHostKeyChecking=no "$NODE" "yq -o=json '.spec.containers[0].command' /etc/kubernetes/manifests/kube-apiserver.yaml" 2>/dev/null)
[ -n "$CMD" ] || { echo "❌ Unable to read the kube-apiserver manifest on the control plane"; exit 1; }

echo "$CMD" | jq -e 'index("--audit-policy-file=/etc/kubernetes/test-audit.yaml") != null' >/dev/null \
  || { echo "❌ kube-apiserver is not configured with --audit-policy-file=/etc/kubernetes/test-audit.yaml"; exit 1; }

export AUDIT_POLICY_FILE=/etc/kubernetes/test-audit.yaml
source "$(dirname "$0")/../lib/audit-policy.sh"
load_audit_policy || exit 1

echo "✅ kube-apiserver uses /etc/kubernetes/test-audit.yaml, a valid audit Policy"
exit 0
