#!/bin/bash
# The fixture Pods were not modified, relabelled, deleted or recreated, AND both backends are
# really covered by the policies (otherwise this check would pass before any work is done)

source "$(dirname "$0")/../lib/q1-lib.sh"
DIR="${Q1_DIR:-/tmp/exam/mhagou-005-q1}"
[ -f "$DIR/.uids" ] || { echo "❌ Internal state file missing"; exit 1; }

NOW=$( { kubectl get pods -n "$NS" -o jsonpath='{range .items[*]}{.metadata.namespace}/{.metadata.name}={.metadata.uid}{"\n"}{end}'; kubectl get pods -n "$PEER" -o jsonpath='{range .items[*]}{.metadata.namespace}/{.metadata.name}={.metadata.uid}{"\n"}{end}'; } 2>/dev/null | sort)
if [ "$NOW" != "$(sort "$DIR/.uids")" ]; then
  echo "❌ The set of Pods changed: the existing test Pods must not be deleted or recreated, and no Pod may be added"
  exit 1
fi
for p in backend-a backend-b frontend database other; do
  kubectl get pod "$p" -n "$NS" -o jsonpath='{.metadata.labels.app}' 2>/dev/null | grep -qx "$([ "$p" = backend-a ] || [ "$p" = backend-b ] && echo backend || echo "$p")" \
    || { echo "❌ The labels of $NS/$p were changed"; exit 1; }
done

init_q1 || exit 1
# both backends covered by an ingress policy and an egress policy: the effects must be visible on both
for spec in "backend-a $IP_BA" "backend-b $IP_BB"; do
  read -r name ip <<< "$spec"
  expect_blocked "Ingress policy of $name" "$NS" other "$ip" 8080 || exit 1
  expect_blocked "Egress policy of $name" "$NS" "$name" "$IP_OT" 8080 || exit 1
done

echo "✅ The fixture Pods are untouched and both backends are covered by ingress and egress policies"
exit 0
