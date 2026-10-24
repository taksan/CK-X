#!/bin/bash
# By behaviour: gvisor-pod is Running and really runs in the gVisor sandbox (dmesg shows the
# gVisor kernel, not the host kernel)

NS="sandbox-test"
PHASE=$(kubectl get pod gvisor-pod -n "$NS" -o jsonpath='{.status.phase}' 2>/dev/null)
[ "$PHASE" = "Running" ] || { echo "❌ Pod 'gvisor-pod' is not running (phase '${PHASE:-none}')"; exit 1; }

if ! kubectl exec -n "$NS" gvisor-pod -- dmesg 2>/dev/null | grep -q "Starting gVisor"; then
  echo "❌ dmesg inside gvisor-pod does not show the gVisor kernel: the Pod does not run in the sandbox"
  exit 1
fi
echo "✅ gvisor-pod runs inside the gVisor sandbox"
exit 0
