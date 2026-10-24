#!/bin/bash
# The Pod apparmor-pod is not privileged and selects the AppArmor profile spectacleapp
# (container level, pod level or the pre-1.30 annotation)

NS="apparmor-lab"
J=$(kubectl get pod apparmor-pod -n "$NS" -o json 2>/dev/null)
[ -n "$J" ] || { echo "❌ Pod 'apparmor-pod' not found in namespace '$NS'"; exit 1; }

if echo "$J" | jq -e '[.spec.containers[], (.spec.initContainers // [])[]] | any(.securityContext.privileged == true)' >/dev/null; then
  echo "❌ A container of the Pod still runs privileged"
  exit 1
fi

PROFILES=$(echo "$J" | jq -r '
  [ (.spec.containers[] | .name as $n | (.securityContext.appArmorProfile // .spec.securityContext.appArmorProfile // empty
        | select(.type == "Localhost") | .localhostProfile),
        (.metadata.annotations["container.apparmor.security.beta.kubernetes.io/" + $n] // empty | sub("^localhost/"; ""))),
    (.spec.securityContext.appArmorProfile // empty | select(.type == "Localhost") | .localhostProfile) ] | unique | join(",")')
if [ -z "$PROFILES" ]; then
  echo "❌ The Pod has no Localhost AppArmor profile configured"
  exit 1
fi
if [ "$PROFILES" != "spectacleapp" ]; then
  echo "❌ The Pod uses the AppArmor profile(s) '$PROFILES', expected spectacleapp"
  exit 1
fi

echo "✅ apparmor-pod is not privileged and uses the AppArmor profile spectacleapp"
exit 0
