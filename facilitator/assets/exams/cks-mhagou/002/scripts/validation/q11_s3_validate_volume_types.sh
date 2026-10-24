#!/bin/bash
# By behaviour: in policy-lab only secret and configMap volumes are accepted (the projected volume
# of the service account token must keep working); emptyDir and hostPath are rejected

source "$(dirname "$0")/../lib/vap-probe.sh"
mk() { echo "  containers: [{name: c, image: busybox:1.36.1, command: [sleep, \"60\"]}]
  volumes: [{name: v, $1}]"; }

# not credited before the policy is effective
for i in $(seq 1 10); do
  OUT=$(probe_pod policy-lab v1 "$(mk 'hostPath: {path: /data}')")
  denied "$OUT" && break
  sleep 3
done
denied "$OUT" || { echo "❌ A Pod with a hostPath volume is accepted in policy-lab"; exit 1; }

denied "$(probe_pod policy-lab v2 "$(mk 'emptyDir: {}')")" || { echo "❌ A Pod with an emptyDir volume is accepted in policy-lab"; exit 1; }
denied "$(probe_pod policy-lab v3 "$(mk 'secret: {secretName: s}')")" && { echo "❌ A Pod with a secret volume is rejected in policy-lab"; exit 1; }
denied "$(probe_pod policy-lab v4 "$(mk 'configMap: {name: c}')")" && { echo "❌ A Pod with a configMap volume is rejected in policy-lab"; exit 1; }
denied "$(probe_pod policy-lab v5 '  containers: [{name: c, image: busybox:1.36.1, command: [sleep, "60"]}]')" && { echo "❌ A Pod without volumes is rejected in policy-lab (the service account token volume must be allowed)"; exit 1; }

echo "✅ policy-lab accepts secret and configMap volumes only"
exit 0
