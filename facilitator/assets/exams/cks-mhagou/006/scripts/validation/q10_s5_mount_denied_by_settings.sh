#!/bin/bash
# Behaviour: a probe Pod with the security settings of audit-pod (same seccomp profile and container
# security context, plus CAP_SYS_ADMIN and no AppArmor profile, so that only the seccomp profile can stop
# the mount: an unprivileged container cannot mount anyway) cannot mount a filesystem; it is removed afterwards

source "$(dirname "$0")/../lib/nodes.sh"

NS="kernel-lab"
NODE="$NODE01"
J=$(kubectl get pod audit-pod -n "$NS" -o json 2>/dev/null)
[ -n "$J" ] || { echo "❌ Pod 'audit-pod' not found in namespace '$NS'"; exit 1; }

PROBE="ckx-probe-$RANDOM"
trap 'kubectl delete pod "$PROBE" -n "$NS" --ignore-not-found --now >/dev/null 2>&1' EXIT

M=$(echo "$J" | jq --arg n "$PROBE" --arg ns "$NS" --arg node "$NODE" '
  (.spec.containers[] | select(.name == "test-container")) as $c |
  {apiVersion: "v1", kind: "Pod", metadata: {name: $n, namespace: $ns},
   spec: {nodeName: $node, restartPolicy: "Never", automountServiceAccountToken: false,
          securityContext: (.spec.securityContext // {}),
          containers: [{name: "probe", image: "busybox:1.36.1", command: ["sh", "-c", "sleep 120"],
                        securityContext: (($c.securityContext // {}) | .capabilities.add = ["SYS_ADMIN"] | .appArmorProfile = {type: "Unconfined"})}]}}')
echo "$M" | kubectl create -f - >/dev/null 2>&1 || { echo "❌ Cannot create a probe Pod with the settings of audit-pod"; exit 1; }
kubectl wait --for=condition=Ready "pod/$PROBE" -n "$NS" --timeout=90s >/dev/null 2>&1 || { echo "❌ A probe Pod with the settings of audit-pod does not start (does the profile file exist on $NODE01?)"; exit 1; }

OUT=$(kubectl exec -n "$NS" "$PROBE" -c probe -- sh -c 'mkdir -p /tmp/ckx-mnt; if mount -t tmpfs -o size=512M tmpfs /tmp/ckx-mnt 2>&1; then umount /tmp/ckx-mnt; echo MOUNTED; fi' 2>&1)
echo "$OUT" | grep -q MOUNTED && { echo "❌ mount succeeds with the settings of audit-pod: the seccomp profile does not block the mount syscall"; exit 1; }
echo "$OUT" | grep -qi -e 'permission denied' -e 'not permitted' || { echo "❌ mount failed for another reason than the seccomp profile: $(echo "$OUT" | head -1 | cut -c1-120)"; exit 1; }

echo "✅ Mounting a filesystem is denied with the seccomp profile of audit-pod"
exit 0
