#!/bin/bash
# Validate no Pod of the ci-cd namespace shares the host PID, IPC or network namespace

NS="ci-cd"

BAD=$(kubectl get pods -n "$NS" -o json 2>/dev/null | jq -r '
  .items[] | select(.metadata.deletionTimestamp == null)
  | select(.spec.hostPID == true or .spec.hostIPC == true or .spec.hostNetwork == true)
  | "\(.metadata.name) (hostPID=\(.spec.hostPID // false) hostIPC=\(.spec.hostIPC // false) hostNetwork=\(.spec.hostNetwork // false))"')

if [ -n "$BAD" ]; then
  echo "❌ These Pods still share namespaces of the node:"
  echo "$BAD" | sed 's/^/   /'
  exit 1
fi

# the Deployment itself must be fixed (the Pods are recreated from it)
if kubectl get deployments -n "$NS" -o json | jq -e '[.items[] | select(.spec.template.spec.hostPID == true or .spec.template.spec.hostIPC == true or .spec.template.spec.hostNetwork == true)] | length > 0' >/dev/null; then
  echo "❌ A Deployment still asks for host namespaces in its Pod template"
  exit 1
fi

echo "✅ No workload in '$NS' shares the PID, IPC or network namespace of the node"
exit 0
