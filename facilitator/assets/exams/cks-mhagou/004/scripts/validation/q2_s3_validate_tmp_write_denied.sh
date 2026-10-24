#!/bin/bash
# Validate by behaviour: in the confined container writing to /tmp fails, while writing elsewhere
# works (so that the denial comes from the profile, not from a read-only filesystem or permissions)

NS="write-guard"
POD="hello-apparmor"

[ "$(kubectl get pod "$POD" -n "$NS" -o jsonpath='{.status.phase}' 2>/dev/null)" = "Running" ] \
  || { echo "❌ Pod '$POD' is not running in namespace '$NS'"; exit 1; }

STATE=$(kubectl exec -n "$NS" "$POD" -- sh -c 'cat /proc/self/attr/apparmor/current 2>/dev/null || cat /proc/self/attr/current' 2>/dev/null)
case "$STATE" in
  *" (enforce)") ;;
  *) echo "❌ The container is not confined by an AppArmor profile in enforce mode ('${STATE:-unknown}')"; exit 1 ;;
esac
case "${STATE% (enforce)}" in
  unconfined|cri-containerd.apparmor.d|docker-default) echo "❌ The container only has the default/unconfined profile"; exit 1 ;;
esac

R=$(kubectl exec -n "$NS" "$POD" -- sh -c '
  if (echo test > /tmp/ckx-apparmor-check) 2>/dev/null; then rm -f /tmp/ckx-apparmor-check; echo TMP_ALLOWED; else echo TMP_DENIED; fi
  if (echo test > /var/ckx-apparmor-check) 2>/dev/null; then rm -f /var/ckx-apparmor-check; echo OTHER_ALLOWED; else echo OTHER_DENIED; fi' 2>/dev/null)

echo "$R" | grep -q TMP_DENIED || { echo "❌ The container can still write to /tmp: the profile does not deny it"; exit 1; }
echo "$R" | grep -q OTHER_ALLOWED || { echo "❌ Writes outside /tmp fail too: the denial must be limited to /tmp"; exit 1; }

echo "✅ Writing to /tmp is denied in the Pod, other paths stay writable"
exit 0
