#!/bin/bash
# Validate the kube-apiserver audit flags: policy file, log path, 5 days and 10 old files

CMD=$(kubectl get pods -n kube-system -l component=kube-apiserver -o jsonpath='{.items[0].spec.containers[0].command}' 2>/dev/null || true)
[ -n "$CMD" ] || { echo "❌ Unable to retrieve the kube-apiserver command from the kube-system namespace"; exit 1; }

echo "$CMD" | grep -q -- '--audit-policy-file=/etc/audit/audit-policy.yaml"' || { echo "❌ kube-apiserver is not configured with --audit-policy-file=/etc/audit/audit-policy.yaml"; exit 1; }

for flag in "--audit-log-path=/var/log/kubernetes-logs.log" "--audit-log-maxage=5" "--audit-log-maxbackup=10"; do
  echo "$CMD" | grep -q -- "$flag\"" || { echo "❌ kube-apiserver is not configured with $flag"; exit 1; }
done

echo "✅ kube-apiserver audit flags are set: policy file, log path, 5 days and 10 old files"
exit 0
