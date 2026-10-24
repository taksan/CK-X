#!/bin/bash
# Item: the API server uses the policy file of the question and writes the log to the requested path

CMD=$(ssh -o StrictHostKeyChecking=no k8s-api-server "yq -o=json '.spec.containers[0].command' /etc/kubernetes/manifests/kube-apiserver.yaml" 2>/dev/null)
[ -n "$CMD" ] || { echo "❌ Unable to read the kube-apiserver manifest on the control plane"; exit 1; }

echo "$CMD" | jq -e 'index("--audit-policy-file=/etc/kubernetes/logpolicy/audit-policy.yaml") != null' >/dev/null \
  || { echo "❌ kube-apiserver is not configured with --audit-policy-file=/etc/kubernetes/logpolicy/audit-policy.yaml"; exit 1; }
echo "$CMD" | jq -e 'index("--audit-log-path=/var/log/kubernetes/logs.txt") != null' >/dev/null \
  || { echo "❌ kube-apiserver is not configured with --audit-log-path=/var/log/kubernetes/logs.txt"; exit 1; }

echo "✅ kube-apiserver uses the policy file and logs to /var/log/kubernetes/logs.txt"
exit 0
