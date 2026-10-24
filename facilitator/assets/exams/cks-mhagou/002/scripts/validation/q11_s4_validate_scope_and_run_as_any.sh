#!/bin/bash
# runAsUser, fsGroup and seLinux stay unrestricted (RunAsAny) in policy-lab and the policy applies
# to policy-lab only (open-lab is unaffected). Credited only when the policy already denies
# privileged Pods in policy-lab.

source "$(dirname "$0")/../lib/vap-probe.sh"
PRIV='  containers: [{name: c, image: busybox:1.36.1, command: [sleep, "60"], securityContext: {privileged: true}}]'
ANY='  securityContext: {runAsUser: 0, fsGroup: 2000, seLinuxOptions: {level: "s0:c1,c2"}, supplementalGroups: [3000]}
  containers: [{name: c, image: busybox:1.36.1, command: [sleep, "60"]}]'
HP='  containers: [{name: c, image: busybox:1.36.1, command: [sleep, "60"]}]
  volumes: [{name: v, hostPath: {path: /data}}]'

denied "$(probe_pod policy-lab a1 "$PRIV")" || { echo "❌ The policy does not deny privileged Pods in policy-lab yet"; exit 1; }
denied "$(probe_pod policy-lab a2 "$ANY")" && { echo "❌ A Pod with runAsUser/fsGroup/seLinuxOptions/supplementalGroups is rejected in policy-lab: these must stay unrestricted (RunAsAny)"; exit 1; }
denied "$(probe_pod open-lab o1 "$PRIV")" && { echo "❌ The policy also affects the namespace open-lab (privileged Pod rejected there)"; exit 1; }
denied "$(probe_pod open-lab o2 "$HP")" && { echo "❌ The policy also affects the namespace open-lab (hostPath volume rejected there)"; exit 1; }

echo "✅ RunAsAny settings are accepted in policy-lab and open-lab is unaffected"
exit 0
