#!/bin/bash
# Validate by behaviour: opening a shell with a terminal in the practice Pod (kubectl exec -it)
# makes Falco on the second worker node log "CRITICAL: SHELL OPENED"

source "$(dirname "$0")/../lib/nodes.sh"

NS="shell-watch"
POD="shell-practice"

[ "$(kubectl get pod "$POD" -n "$NS" -o jsonpath='{.status.phase}' 2>/dev/null)" = "Running" ] \
  || { echo "❌ Pod '$POD' is not running in namespace '$NS'"; exit 1; }
[ "$(kubectl get pod "$POD" -n "$NS" -o jsonpath='{.spec.nodeName}' 2>/dev/null)" = "$NODE02" ] \
  || { echo "❌ Pod '$POD' does not run on $NODE02"; exit 1; }

# Falco needs several seconds after a (re)start to load its rules and open the probe: wait until the
# service has been running for at least 15 seconds, otherwise the test shell would be missed
UP=no
for i in $(seq 1 60); do
  if ssh -o StrictHostKeyChecking=no "$NODE02" 'bash -s' >/dev/null 2>&1 <<'EOF'
UNIT=$(systemctl list-units 'falco-*' --state=active --no-legend 2>/dev/null | grep -v falcoctl | awk '{print $1}' | head -1)
[ -n "$UNIT" ] || exit 1
PID=$(systemctl show -p MainPID --value "$UNIT")
AGE=$(ps -o etimes= -p "$PID" 2>/dev/null | tr -d ' ')
[ -n "$AGE" ] && [ "$AGE" -ge 15 ]
EOF
  then UP=yes; break; fi
  sleep 2
done
[ "$UP" = "yes" ] || { echo "❌ Falco is not running on $NODE02 (or keeps restarting): run 'falco -o engine.kind=modern_ebpf' on the node to see the rule error (a YAML value that contains ': ' must be quoted)"; exit 1; }

SINCE=$(ssh -o StrictHostKeyChecking=no "$NODE02" 'date -u "+%Y-%m-%d %H:%M:%S"' 2>/dev/null)
[ -n "$SINCE" ] || { echo "❌ Cannot reach $NODE02 over ssh"; exit 1; }
sleep 1

# script gives kubectl a terminal even though the validator has none
timeout 25 script -q -e -c "kubectl -n $NS exec -it $POD -- /bin/sh -c 'sleep 2'" /dev/null >/dev/null 2>&1

FOUND=no
for i in $(seq 1 30); do
  if ssh -o StrictHostKeyChecking=no "$NODE02" "journalctl _COMM=falco --since '$SINCE UTC' --no-pager -o cat 2>/dev/null | grep -qF 'CRITICAL: SHELL OPENED'" 2>/dev/null; then
    FOUND=yes; break
  fi
  sleep 1
done

[ "$FOUND" = "yes" ] || { echo "❌ Falco on $NODE02 did not log 'CRITICAL: SHELL OPENED' after a shell with a terminal was opened in the Pod (journalctl -u falco-modern-bpf on $NODE02 shows what Falco logged)"; exit 1; }

echo "✅ Falco on $NODE02 logs 'CRITICAL: SHELL OPENED' when a shell is opened in a container"
exit 0
