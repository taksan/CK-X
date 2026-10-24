#!/bin/bash
# Validate the policy is actually enforced (server-side dry-run, nothing is created)

NS="secure-apps"
OTHER_NS="open-apps"   # a namespace outside the policy scope, used only by this question
BAD="nginx:1.25"
GOOD="registry.k8s.io/pause:3.10"

# the policy can take a few seconds to become active after it is created
DENIED=""
for i in $(seq 1 10); do
  OUT=$(kubectl run policy-check-bad -n "$NS" --image="$BAD" --restart=Never --dry-run=server 2>&1)
  # the rejection must come from the admission policy, not from another error
  if [ $? -ne 0 ] && echo "$OUT" | grep -q "ValidatingAdmissionPolicy"; then
    DENIED="yes"
    break
  fi
  sleep 2
done

if [ -z "$DENIED" ]; then
  echo "❌ A Pod using '$BAD' is not rejected in namespace '$NS'"
  exit 1
fi

if ! kubectl run policy-check-good -n "$NS" --image="$GOOD" --restart=Never --dry-run=server >/dev/null 2>&1; then
  echo "❌ A Pod using '$GOOD' is rejected in namespace '$NS' but it should be accepted"
  exit 1
fi

if ! kubectl run policy-check-other -n "$OTHER_NS" --image="$BAD" --restart=Never --dry-run=server >/dev/null 2>&1; then
  echo "❌ The policy also rejects Pods in '$OTHER_NS', outside the '$NS' namespace; it must be scoped to '$NS'"
  exit 1
fi

echo "✅ '$BAD' is rejected in '$NS', '$GOOD' is accepted, other namespaces are unaffected"
exit 0
