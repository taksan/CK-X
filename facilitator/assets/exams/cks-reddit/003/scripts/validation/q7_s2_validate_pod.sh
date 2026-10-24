#!/bin/bash
# Validate Pod untrusted (alpine:3.18) runs in the sandbox namespace on node02 with the untrusted RuntimeClass

source "$(dirname "$0")/../lib/nodes.sh"

NS="sandbox"

JSON=$(kubectl get pod untrusted -n "$NS" -o json 2>/dev/null)
if [ -z "$JSON" ]; then
  echo "❌ Pod 'untrusted' not found in namespace '$NS'"
  exit 1
fi

if [ "$(echo "$JSON" | jq -r '.spec.runtimeClassName // ""')" != "untrusted" ]; then
  echo "❌ Pod 'untrusted' does not use runtimeClassName 'untrusted'"
  exit 1
fi

if [ "$(echo "$JSON" | jq -r '.spec.nodeName // ""')" != "$NODE02" ]; then
  echo "❌ Pod 'untrusted' is not running on $NODE02 (node: $(echo "$JSON" | jq -r '.spec.nodeName // "none"'))"
  exit 1
fi

if ! echo "$JSON" | jq -e '[.spec.containers[].image] | any(. == "alpine:3.18")' >/dev/null; then
  echo "❌ Pod 'untrusted' does not use the image alpine:3.18"
  exit 1
fi

PHASE=$(echo "$JSON" | jq -r '.status.phase')
if [ "$PHASE" != "Running" ]; then
  echo "❌ Pod 'untrusted' is not running (phase: $PHASE)"
  exit 1
fi

echo "✅ Pod 'untrusted' runs on $NODE02 with the 'untrusted' RuntimeClass"
exit 0
