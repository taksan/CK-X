#!/bin/bash
# Validate kube-apiserver kube-bench flags: profiling disabled, service account lookup enabled

CMD=$(kubectl get pods -n kube-system -l component=kube-apiserver -o jsonpath='{.items[0].spec.containers[0].command}' 2>/dev/null || true)
if [ -z "$CMD" ]; then
  echo "❌ Unable to retrieve kube-apiserver command from kube-system namespace"
  exit 1
fi

if ! echo "$CMD" | grep -q -- "--profiling=false"; then
  echo "❌ kube-apiserver does not have --profiling=false"
  exit 1
fi

# true is the default, so the flag may be absent, but it must not be false
if echo "$CMD" | grep -q -- "--service-account-lookup=false"; then
  echo "❌ kube-apiserver still has --service-account-lookup=false"
  exit 1
fi

echo "✅ kube-apiserver has --profiling=false and service account lookup enabled"
exit 0
