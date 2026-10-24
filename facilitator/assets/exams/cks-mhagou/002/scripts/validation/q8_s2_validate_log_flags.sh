#!/bin/bash
# kube-apiserver writes the audit log to /var/log/test-audit.log and keeps it 20 days

source "$(dirname "$0")/../lib/nodes.sh"
NODE="${CONTROL_PLANE}"
CMD=$(ssh -o StrictHostKeyChecking=no "$NODE" "yq -o=json '.spec.containers[0].command' /etc/kubernetes/manifests/kube-apiserver.yaml" 2>/dev/null)
[ -n "$CMD" ] || { echo "❌ Unable to read the kube-apiserver manifest on the control plane"; exit 1; }

for flag in "--audit-log-path=/var/log/test-audit.log" "--audit-log-maxage=20"; do
  echo "$CMD" | jq -e --arg f "$flag" 'index($f) != null' >/dev/null || { echo "❌ kube-apiserver is not configured with $flag"; exit 1; }
done

echo "✅ Audit log path /var/log/test-audit.log and retention of 20 days are configured"
exit 0
