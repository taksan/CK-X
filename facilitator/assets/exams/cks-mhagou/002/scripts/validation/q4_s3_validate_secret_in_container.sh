#!/bin/bash
# By behaviour: secretpod is Running and the secret files can be read in the container, read-only

NS="secret-lab"
J=$(kubectl get pod secretpod -n "$NS" -o json 2>/dev/null)
[ -n "$J" ] || { echo "❌ Pod 'secretpod' not found in namespace '$NS'"; exit 1; }
[ "$(echo "$J" | jq -r '.status.phase')" = "Running" ] || { echo "❌ Pod 'secretpod' is not running"; exit 1; }

VOL=$(echo "$J" | jq -r '[.spec.volumes[]? | select(.secret.secretName == "secret1")][0].name // empty')
[ -n "$VOL" ] || { echo "❌ The Pod does not mount the Secret 'secret1'"; exit 1; }
CNAME=$(echo "$J" | jq -r --arg v "$VOL" '[.spec.containers[] | select(any(.volumeMounts[]?; .name == $v))][0].name')
MP=$(echo "$J" | jq -r --arg v "$VOL" '[.spec.containers[].volumeMounts[]? | select(.name == $v)][0].mountPath')

GOT=$(kubectl exec -n "$NS" secretpod -c "$CNAME" -- cat "$MP/user" 2>/dev/null)
[ "$GOT" = "admin" ] || { echo "❌ $MP/user in the container is '$GOT', expected 'admin'"; exit 1; }
if kubectl exec -n "$NS" secretpod -c "$CNAME" -- sh -c "touch '$MP/ckx-write-test'" >/dev/null 2>&1; then
  echo "❌ The secret volume is writable in the container"
  exit 1
fi

echo "✅ The secret is readable at $MP and the mount is read-only"
exit 0
