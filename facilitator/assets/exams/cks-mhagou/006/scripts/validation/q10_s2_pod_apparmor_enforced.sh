#!/bin/bash
# Pod hello-apparmor runs on node01 with the Localhost profile k8s-apparmor-example-deny-write and the
# profile is enforced on the running process

source "$(dirname "$0")/../lib/runtime-q10.sh"
J=$(kubectl get pod hello-apparmor -n "$NS" -o json 2>/dev/null)
[ -n "$J" ] || { echo "❌ Pod 'hello-apparmor' not found in namespace '$NS'"; exit 1; }
[ "$(echo "$J" | jq -r '.status.phase')" = "Running" ] || { echo "❌ Pod 'hello-apparmor' is not running"; exit 1; }

PROFILE=$(echo "$J" | jq -r '
  (.spec.containers[] | select(.name == "hello") | .securityContext.appArmorProfile) as $c
  | ($c // .spec.securityContext.appArmorProfile) as $p
  | if $p.type == "Localhost" then $p.localhostProfile
    else (.metadata.annotations["container.apparmor.security.beta.kubernetes.io/hello"] // "") | ltrimstr("localhost/") end')
[ "$PROFILE" = "k8s-apparmor-example-deny-write" ] || { echo "❌ The Pod does not use the Localhost AppArmor profile k8s-apparmor-example-deny-write (found '$PROFILE')"; exit 1; }

pod_proc_state hello-apparmor hello || { echo "❌ Cannot read the process state of the container on $NODE"; exit 1; }
[ "$ARMOR" = "k8s-apparmor-example-deny-write (enforce)" ] || { echo "❌ The running process is confined by '$ARMOR', expected 'k8s-apparmor-example-deny-write (enforce)'"; exit 1; }

echo "✅ Pod 'hello-apparmor' runs with the AppArmor profile enforced"
exit 0
