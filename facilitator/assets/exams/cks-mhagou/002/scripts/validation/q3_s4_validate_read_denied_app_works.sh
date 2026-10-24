#!/bin/bash
# By behaviour: apparmor-pod is Running, reading /data/records is denied, and the web server still
# answers (the profile must not break the application)

source "$(dirname "$0")/../lib/nodes.sh"
NS="apparmor-lab"
J=$(kubectl get pod apparmor-pod -n "$NS" -o json 2>/dev/null)
[ -n "$J" ] || { echo "❌ Pod 'apparmor-pod' not found in namespace '$NS'"; exit 1; }

[ "$(echo "$J" | jq -r '.status.phase')" = "Running" ] || { echo "❌ Pod 'apparmor-pod' is not running (is the profile loaded on ${NODE01}?)"; exit 1; }
[ "$(echo "$J" | jq -r '.spec.nodeName')" = "${NODE01}" ] || { echo "❌ Pod 'apparmor-pod' does not run on ${NODE01}, where the profile is"; exit 1; }

if kubectl exec -n "$NS" apparmor-pod -c nginx -- cat /data/records/read-test >/dev/null 2>&1; then
  echo "❌ The container can still read /data/records/read-test: the profile is not enforced"
  exit 1
fi
if ! kubectl exec -n "$NS" apparmor-pod -c nginx -- wget -q -T 4 -O /dev/null http://127.0.0.1:80/ >/dev/null 2>&1; then
  echo "❌ The web server of the container does not answer anymore"
  exit 1
fi

echo "✅ Reading /data/records is denied inside apparmor-pod and the web server still answers"
exit 0
