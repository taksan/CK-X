#!/bin/bash
# Source this file (question 3). Runs ONE probe Pod on node01 that opens the harmless files
# /dev/mem and /dev/mem2 (a fixture mounted over those names, nothing real is read) while it reads
# the journal of node01, and keeps the captured journal for 2 minutes so that the three validators
# of the question share one run. Sets PROBE_JOURNAL (file on the jumphost) or prints the reason and
# returns 1.

source "$(dirname "${BASH_SOURCE[0]}")/nodes.sh"
FALCO_NODE="${NODE01}"
FALCO_NS="memory-watch"
PROBE_JOURNAL="/tmp/ckx-mhagou003-q3-journal"
PROBE_STAMP="/tmp/ckx-mhagou003-q3-stamp"

run_devmem_probe() {
  # reuse a recent run (a lock avoids two validators running the probe at the same time)
  exec 9>/tmp/ckx-mhagou003-q3.lock
  flock 9
  if [ -s "$PROBE_JOURNAL" ] && [ -f "$PROBE_STAMP" ] && [ $(( $(date +%s) - $(cat "$PROBE_STAMP") )) -lt 120 ]; then
    return 0
  fi

  local name="ckx-probe-$RANDOM$RANDOM" start
  start=$(ssh -o StrictHostKeyChecking=no "$FALCO_NODE" 'date +%s' 2>/dev/null)
  [ -n "$start" ] || { echo "❌ Cannot reach $FALCO_NODE over ssh"; return 1; }

  if ! kubectl apply -f - >/dev/null 2>&1 <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: ${name}
  namespace: ${FALCO_NS}
spec:
  nodeName: ${FALCO_NODE}
  restartPolicy: Never
  terminationGracePeriodSeconds: 0
  volumes:
  - name: fixture
    emptyDir: {}
  initContainers:
  - name: fixture
    image: busybox:1.36.1
    command: ["sh", "-c", "echo harmless > /fixture/mem"]
    volumeMounts:
    - {name: fixture, mountPath: /fixture}
  containers:
  - name: probe
    image: busybox:1.36.1
    command: ["sh", "-c", "i=0; while [ \$i -lt 30 ]; do cat /dev/mem >/dev/null; cat /dev/mem2 >/dev/null; i=\$((i+1)); sleep 2; done"]
    volumeMounts:
    - {name: fixture, mountPath: /dev/mem, subPath: mem, readOnly: true}
    - {name: fixture, mountPath: /dev/mem2, subPath: mem, readOnly: true}
EOF
  then
    echo "❌ The validation probe Pod cannot be created in the namespace $FALCO_NS"
    return 1
  fi

  # let the probe read for a while (Falco has to see the events and, after a rule change, to reload)
  sleep 45
  ssh -o StrictHostKeyChecking=no "$FALCO_NODE" "journalctl --since '@$start' --no-pager -o cat" > "$PROBE_JOURNAL" 2>/dev/null
  date +%s > "$PROBE_STAMP"
  kubectl delete pod "$name" -n "$FALCO_NS" --ignore-not-found --force --grace-period=0 >/dev/null 2>&1
  return 0
}
