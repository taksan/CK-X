#!/bin/bash
# Behaviour: in Pod hello-apparmor creating a directory is denied

NS="kernel-lab"
[ "$(kubectl get pod hello-apparmor -n "$NS" -o jsonpath='{.status.phase}' 2>/dev/null)" = "Running" ] || { echo "❌ Pod 'hello-apparmor' is not running"; exit 1; }

OUT=$(kubectl exec -n "$NS" hello-apparmor -c hello -- sh -c 'd=/ckx-write-test-$$; if mkdir "$d" 2>&1; then rmdir "$d"; echo CREATED; fi' 2>&1)
echo "$OUT" | grep -q CREATED && { echo "❌ mkdir succeeds in Pod 'hello-apparmor': the AppArmor profile does not deny writes (add 'deny /** w,')"; exit 1; }
echo "$OUT" | grep -qi 'permission denied' || { echo "❌ mkdir in Pod 'hello-apparmor' failed for another reason than the profile: $(echo "$OUT" | head -1 | cut -c1-120)"; exit 1; }

echo "✅ Creating a directory in Pod 'hello-apparmor' is denied (Permission denied)"
exit 0
