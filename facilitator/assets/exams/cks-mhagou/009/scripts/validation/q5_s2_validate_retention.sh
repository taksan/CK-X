#!/bin/bash
# Item: logs kept for 5 days, at most 10 old files

CMD=$(ssh -o StrictHostKeyChecking=no k8s-api-server "yq -o=json '.spec.containers[0].command' /etc/kubernetes/manifests/kube-apiserver.yaml" 2>/dev/null)
[ -n "$CMD" ] || { echo "❌ Unable to read the kube-apiserver manifest on the control plane"; exit 1; }

for flag in "--audit-log-maxage=5" "--audit-log-maxbackup=10"; do
  echo "$CMD" | jq -e --arg f "$flag" 'index($f) != null' >/dev/null || { echo "❌ kube-apiserver is not configured with $flag"; exit 1; }
done

echo "✅ Audit log retention: 5 days, 10 old files"
exit 0
