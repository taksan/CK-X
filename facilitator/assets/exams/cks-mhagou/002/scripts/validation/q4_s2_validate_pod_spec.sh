#!/bin/bash
# Pod secretpod uses the nginx image and mounts secret1 as a volume with the readOnly option

NS="secret-lab"
J=$(kubectl get pod secretpod -n "$NS" -o json 2>/dev/null)
[ -n "$J" ] || { echo "❌ Pod 'secretpod' not found in namespace '$NS'"; exit 1; }

echo "$J" | jq -e '[.spec.containers[].image] | any(startswith("nginx") or test("/nginx(:|$)"))' >/dev/null \
  || { echo "❌ The Pod does not use the nginx image"; exit 1; }

VOL=$(echo "$J" | jq -r '[.spec.volumes[]? | select(.secret.secretName == "secret1")][0].name // empty')
[ -n "$VOL" ] || { echo "❌ The Pod does not mount the Secret 'secret1' as a volume"; exit 1; }

if ! echo "$J" | jq -e --arg v "$VOL" '[.spec.containers[].volumeMounts[]? | select(.name == $v)] | length > 0 and all(.[]; .readOnly == true)' >/dev/null; then
  echo "❌ The volume of the Secret must be mounted with readOnly: true"
  exit 1
fi

echo "✅ secretpod (nginx) mounts secret1 as a read-only volume"
exit 0
