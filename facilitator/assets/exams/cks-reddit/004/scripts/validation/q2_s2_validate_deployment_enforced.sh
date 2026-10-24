#!/bin/bash
# Validate Deployment webapp runs with a Localhost seccomp profile and that the profile is enforced:
# creating a directory fails, other operations work

source "$(dirname "$0")/../lib/nodes.sh"

NS="secure-app"

JSON=$(kubectl get deployment webapp -n "$NS" -o json 2>/dev/null)
[ -n "$JSON" ] || { echo "❌ Deployment 'webapp' not found in namespace '$NS'"; exit 1; }

PROFILE=$(echo "$JSON" | jq -r '.spec.template.spec.containers[0].securityContext.seccompProfile // .spec.template.spec.securityContext.seccompProfile | select(.type == "Localhost") | .localhostProfile // empty')
if [ -z "$PROFILE" ]; then
  echo "❌ The Deployment does not use a Localhost seccomp profile"
  exit 1
fi

WANT=$(echo "$JSON" | jq -r '.spec.replicas')

# the rollout must be complete: every replica updated and ready, no old Pod left over
for i in $(seq 1 20); do
  ST=$(kubectl get deployment webapp -n "$NS" -o json | jq -c '{u: (.status.updatedReplicas // 0), r: (.status.readyReplicas // 0), t: (.status.replicas // 0)}')
  [ "$ST" = "{\"u\":$WANT,\"r\":$WANT,\"t\":$WANT}" ] && break
  sleep 3
done
if [ "$ST" != "{\"u\":$WANT,\"r\":$WANT,\"t\":$WANT}" ]; then
  echo "❌ The rollout is not complete (status $ST): does the profile '$PROFILE' exist on $NODE01?"
  exit 1
fi

for pod in $(kubectl get pods -n "$NS" -l app=webapp -o jsonpath='{.items[?(@.metadata.deletionTimestamp==null)].metadata.name}'); do
  if ! kubectl get pod "$pod" -n "$NS" -o json | jq -e '(.spec.containers[0].securityContext.seccompProfile // .spec.securityContext.seccompProfile).type == "Localhost"' >/dev/null; then
    echo "❌ Pod $pod does not run with the Localhost seccomp profile"
    exit 1
  fi
  if kubectl exec -n "$NS" "$pod" -- mkdir /tmp/ckx-seccomp-test >/dev/null 2>&1; then
    echo "❌ Pod $pod can create a directory: the seccomp profile is not enforced"
    exit 1
  fi
  if ! kubectl exec -n "$NS" "$pod" -- touch /tmp/ckx-seccomp-file >/dev/null 2>&1; then
    echo "❌ Pod $pod cannot create a file: the profile blocks more than mkdir"
    exit 1
  fi
done

echo "✅ webapp runs with the Localhost seccomp profile '$PROFILE': mkdir is blocked, other operations work"
exit 0
