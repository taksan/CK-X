#!/bin/bash
# Validate the retention flags: 500 MB, 5 old files, 7 days

CMD=$(ssh -o StrictHostKeyChecking=no k8s-api-server "yq -o=json '.spec.containers[0].command' /etc/kubernetes/manifests/kube-apiserver.yaml" 2>/dev/null)
[ -n "$CMD" ] || { echo "❌ Unable to read the kube-apiserver manifest on the control plane"; exit 1; }

for flag in "--audit-log-maxsize=500" "--audit-log-maxbackup=5" "--audit-log-maxage=7"; do
  echo "$CMD" | jq -e --arg f "$flag" 'index($f) != null' >/dev/null || { echo "❌ kube-apiserver is not configured with $flag"; exit 1; }
done

echo "✅ Retention: 500 MB, 5 old files, 7 days"
exit 0
