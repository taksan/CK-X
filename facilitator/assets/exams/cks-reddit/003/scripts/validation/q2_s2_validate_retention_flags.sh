#!/bin/bash
# Validate the retention flags: 12 days, 8 old files, 200 MB

CMD=$(ssh -o StrictHostKeyChecking=no k8s-api-server "yq -o=json '.spec.containers[0].command' /etc/kubernetes/manifests/kube-apiserver.yaml" 2>/dev/null)
[ -n "$CMD" ] || { echo "❌ Unable to read the kube-apiserver manifest on the control plane"; exit 1; }

for flag in "--audit-log-maxage=12" "--audit-log-maxbackup=8" "--audit-log-maxsize=200"; do
  echo "$CMD" | jq -e --arg f "$flag" 'index($f) != null' >/dev/null || { echo "❌ kube-apiserver is not configured with $flag"; exit 1; }
done

echo "✅ Retention: 12 days, 8 old files, 200 MB"
exit 0
