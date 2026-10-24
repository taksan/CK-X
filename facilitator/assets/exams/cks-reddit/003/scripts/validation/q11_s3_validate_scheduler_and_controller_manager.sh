#!/bin/bash
# Validate profiling is disabled on the kube-controller-manager and the kube-scheduler

for component in kube-controller-manager kube-scheduler; do
  CMD=$(kubectl get pods -n kube-system -l "component=$component" -o jsonpath='{.items[0].spec.containers[0].command}' 2>/dev/null)
  if [ -z "$CMD" ]; then
    echo "❌ Could not read the command of $component"
    exit 1
  fi
  if ! echo "$CMD" | grep -q -- '--profiling=false'; then
    echo "❌ $component does not have --profiling=false"
    exit 1
  fi
done

echo "✅ kube-controller-manager and kube-scheduler have --profiling=false"
exit 0
