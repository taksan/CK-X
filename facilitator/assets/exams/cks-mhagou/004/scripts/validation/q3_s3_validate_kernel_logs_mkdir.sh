#!/bin/bash
# Validate by behaviour that the kernel of the second worker node really logs the mkdir calls of the Pod:
# run mkdir in the container and look for the seccomp audit record (type=1326, comm="mkdir")

source "$(dirname "$0")/../lib/nodes.sh"

NS="syscall-lab"
POD="audit-pod"

[ "$(kubectl get pod "$POD" -n "$NS" -o jsonpath='{.status.phase}' 2>/dev/null)" = "Running" ] \
  || { echo "❌ Pod '$POD' is not running in namespace '$NS'"; exit 1; }
[ "$(kubectl get pod "$POD" -n "$NS" -o jsonpath='{.spec.nodeName}' 2>/dev/null)" = "$NODE02" ] \
  || { echo "❌ Pod '$POD' does not run on $NODE02"; exit 1; }

SINCE=$(ssh -o StrictHostKeyChecking=no "$NODE02" 'date "+%Y-%m-%d %H:%M:%S"' 2>/dev/null)
[ -n "$SINCE" ] || { echo "❌ Cannot reach $NODE02 over ssh"; exit 1; }
sleep 1
kubectl exec -n "$NS" "$POD" -- sh -c 'p=/tmp/ckx-seccomp-log-$$; /bin/mkdir "$p" && /bin/rmdir "$p"' >/dev/null 2>&1

FOUND=no
for i in $(seq 1 10); do
  if ssh -o StrictHostKeyChecking=no "$NODE02" "journalctl -k --since '$SINCE' --no-pager 2>/dev/null | grep 'type=1326' | grep -q 'comm=\"mkdir\"'" 2>/dev/null; then
    FOUND=yes; break
  fi
  sleep 2
done

[ "$FOUND" = "yes" ] || { echo "❌ The kernel of $NODE02 did not log the mkdir of the Pod (no seccomp audit record type=1326 for comm=\"mkdir\"): is the profile applied and does it log (SCMP_ACT_LOG) mkdir and mkdirat?"; exit 1; }

echo "✅ The kernel of $NODE02 logs the mkdir calls of the Pod"
exit 0
