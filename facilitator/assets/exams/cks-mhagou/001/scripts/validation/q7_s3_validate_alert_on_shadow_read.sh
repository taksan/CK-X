#!/bin/bash
# Item (by behaviour): when a process of a Pod reads /etc/shadow, Falco logs a WARNING that starts with
# "SHADOW READ" - for different processes (cat and head), as the rule is for "any process"
source "$(dirname "$0")/../lib/nodes.sh"

NS="shadow-watch"
kubectl get pod report-agent -n "$NS" >/dev/null 2>&1 || { echo "❌ The test Pod report-agent is not available in $NS"; exit 1; }
ssh -o StrictHostKeyChecking=no node01 'systemctl is-active --quiet falco-modern-bpf' || { echo "❌ The Falco service of $NODE01 is not running"; exit 1; }

# let Falco settle after a restart (it needs ~10-15 s to watch the new container)
UP=$(ssh -o StrictHostKeyChecking=no node01 'echo $(( $(date +%s) - $(date -d "$(systemctl show -p ActiveEnterTimestamp --value falco-modern-bpf)" +%s) ))' 2>/dev/null)
[ "${UP:-0}" -ge 15 ] || sleep $(( 15 - ${UP:-0} ))

check() { # process-command label
  local since
  since=$(ssh -o StrictHostKeyChecking=no node01 'date -u +"%Y-%m-%d %H:%M:%S"')
  kubectl exec -n "$NS" report-agent -- sh -c "$1" >/dev/null 2>&1
  local i
  for i in $(seq 1 8); do
    if ssh -o StrictHostKeyChecking=no node01 "journalctl -u falco-modern-bpf --since '$since' --no-pager 2>/dev/null | grep -E 'Warning' | grep -q 'SHADOW READ'"; then
      return 0
    fi
    sleep 2
  done
  return 1
}

check 'cat /etc/shadow' || { echo "❌ No Falco WARNING starting with 'SHADOW READ' after 'cat /etc/shadow' in a Pod (is the rule loaded and is its priority WARNING?)"; exit 1; }
check 'head -n 1 /etc/shadow' || { echo "❌ No 'SHADOW READ' WARNING after 'head -n 1 /etc/shadow': the rule must fire for any process"; exit 1; }

echo "✅ Falco logs a 'SHADOW READ' WARNING when processes read /etc/shadow"
exit 0
