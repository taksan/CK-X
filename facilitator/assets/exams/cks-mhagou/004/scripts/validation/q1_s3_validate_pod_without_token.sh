#!/bin/bash
# Validate a Pod uses hidden-user, runs (or completed) and has no automatic token mount:
# neither enabled again on the Pod nor a projected token volume at the usual path

NS="secret-room"
PODS=$(kubectl get pods -n "$NS" -o json 2>/dev/null)
[ -n "$PODS" ] || { echo "❌ Unable to list the Pods of namespace '$NS'"; exit 1; }

USING=$(echo "$PODS" | jq -r '[.items[] | select(.spec.serviceAccountName == "hidden-user" and .metadata.deletionTimestamp == null)] | length')
[ "$USING" -gt 0 ] || { echo "❌ No Pod in '$NS' uses the ServiceAccount hidden-user"; exit 1; }

GOOD=$(echo "$PODS" | jq -r '
  [ .items[]
    | select(.spec.serviceAccountName == "hidden-user" and .metadata.deletionTimestamp == null)
    | select(.status.phase == "Running" or .status.phase == "Succeeded")
    | select(.spec.automountServiceAccountToken != true)
    | . as $p
    | select(([ ($p.spec.volumes // [])[] | select(.projected != null and any(.projected.sources[]?; .serviceAccountToken != null)) | .name ] as $vols
              | [ ($p.spec.containers + ($p.spec.initContainers // []))[] | (.volumeMounts // [])[]
                  | select(.mountPath == "/var/run/secrets/kubernetes.io/serviceaccount" and (.name as $n | $vols | index($n) != null)) ] | length) == 0)
    | .metadata.name ] | first // empty')

if [ -z "$GOOD" ]; then
  echo "❌ No Pod using hidden-user is running (or completed) without an automatic token mount (found $USING Pod(s) using it)"
  exit 1
fi

echo "✅ Pod '$GOOD' uses hidden-user without an automatic token mount"
exit 0
