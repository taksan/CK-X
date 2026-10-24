#!/bin/bash
# By behaviour: a privileged Pod is rejected in policy-lab, an unprivileged one is accepted

source "$(dirname "$0")/../lib/vap-probe.sh"
PRIV='  containers: [{name: c, image: busybox:1.36.1, command: [sleep, "60"], securityContext: {privileged: true}}]'
INIT='  initContainers: [{name: i, image: busybox:1.36.1, command: ["true"], securityContext: {privileged: true}}]
  containers: [{name: c, image: busybox:1.36.1, command: [sleep, "60"]}]'
PLAIN='  containers: [{name: c, image: busybox:1.36.1, command: [sleep, "60"], securityContext: {privileged: false}}]'

for i in $(seq 1 10); do
  OUT=$(probe_pod policy-lab p1 "$PRIV")
  denied "$OUT" && break
  sleep 3
done
denied "$OUT" || { echo "❌ A privileged Pod is accepted in policy-lab"; exit 1; }
denied "$(probe_pod policy-lab p2 "$INIT")" || { echo "❌ A Pod with a privileged init container is accepted in policy-lab"; exit 1; }
denied "$(probe_pod policy-lab p3 "$PLAIN")" && { echo "❌ An unprivileged Pod is rejected in policy-lab"; exit 1; }

echo "✅ Privileged Pods are rejected in policy-lab"
exit 0
