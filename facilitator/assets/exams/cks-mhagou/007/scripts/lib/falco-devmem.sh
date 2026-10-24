#!/bin/bash
# Source this file (question 9). run_devmem_falco starts a standalone Falco on node01 with the same rule files
# as the system service (the default rules and /etc/falco/falco_rules.local.yaml) for ~30 s, never touching the
# service, while this host makes the Pod test-falco read /dev/mem. It sets DEVMEM_JSON (the JSON events).
# The result is cached for 2 minutes per content of the local rules file (several validators use it).
# Returns 1 and prints the reason when Falco does not run with the local rules.

source "$(dirname "${BASH_SOURCE[0]}")/nodes.sh"
DM_NODE="node01"   # ssh alias of the first worker
DEVMEM_JSON=""

run_devmem_falco() {
  local content key cache RAW
  content=$(ssh -o StrictHostKeyChecking=no "$DM_NODE" "cat /etc/falco/falco_rules.local.yaml" 2>/dev/null)
  [ -n "$content" ] || { echo "❌ /etc/falco/falco_rules.local.yaml of $NODE01 does not exist or is empty"; return 1; }
  key=$(printf '%s' "$content" | md5sum | cut -c1-12)
  cache="/tmp/ckx-falco-devmem.$key"
  if [ -f "$cache" ] && [ $(( $(date +%s) - $(stat -c %Y "$cache") )) -lt 120 ]; then
    RAW=$(cat "$cache")
  else
    ( for i in $(seq 1 16); do sleep 2; kubectl exec -n devmem-lab test-falco -- sh -c 'cat /dev/mem >/dev/null 2>&1' >/dev/null 2>&1; done ) &
    local trig=$!
    RAW=$(ssh -o StrictHostKeyChecking=no "$DM_NODE" 'bash -s' <<'REMOTE'
timeout 90 falco -r /etc/falco/falco_rules.yaml -r /etc/falco/falco_rules.local.yaml -M 30 -o json_output=true \
  -o stdout_output.enabled=true -o file_output.enabled=false -o syslog_output.enabled=false \
  -o program_output.enabled=false -o http_output.enabled=false -o webserver.enabled=false >/tmp/ckx-val-devmem.out 2>/tmp/ckx-val-devmem.err
echo "#RC=$?"
cat /tmp/ckx-val-devmem.out
echo "#ERR"
grep -iE 'error|invalid|undefined|unknown|cannot' /tmp/ckx-val-devmem.err | head -2
rm -f /tmp/ckx-val-devmem.out /tmp/ckx-val-devmem.err
REMOTE
)
    wait $trig 2>/dev/null
    printf '%s\n' "$RAW" > "$cache"
  fi
  if ! echo "$RAW" | grep -q '^#RC=0'; then
    echo "❌ Falco does not run with the rule files (default rules + /etc/falco/falco_rules.local.yaml): $(echo "$RAW" | sed -n '/^#ERR/,$p' | sed 1d | head -1 | cut -c1-200)"
    return 1
  fi
  DEVMEM_JSON=$(echo "$RAW" | sed '/^#ERR/,$d' | jq -cR 'fromjson? | select(type == "object")' 2>/dev/null)
}

devmem_container_id() {
  kubectl get pod test-falco -n devmem-lab -o jsonpath='{.status.containerStatuses[0].containerID}' 2>/dev/null | sed 's#.*://##' | cut -c1-12
}
