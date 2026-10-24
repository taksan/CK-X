#!/bin/bash
# Behaviour: the kernel log inside the Pod is the one of gVisor

NS="gvisor-lab"
[ "$(kubectl get pod secure -n "$NS" -o jsonpath='{.status.phase}' 2>/dev/null)" = "Running" ] || { echo "❌ Pod 'secure' is not running in namespace '$NS'"; exit 1; }
kubectl exec -n "$NS" secure -- dmesg 2>/dev/null | grep -qi 'gvisor' || { echo "❌ dmesg in Pod 'secure' does not show gVisor: the Pod is not sandboxed"; exit 1; }

echo "✅ dmesg in Pod 'secure' shows gVisor"
exit 0
