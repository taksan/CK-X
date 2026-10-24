#!/bin/bash
# Validate a running Pod in namespace safe mounts the secret newsecret as a volume

NS="safe"

POD=$(kubectl get pods -n "$NS" -o json 2>/dev/null | jq -r '
  .items[] | select(.metadata.deletionTimestamp == null and .status.phase == "Running")
  | select([ .spec.volumes[]? | (.secret.secretName // empty), (.projected.sources[]?.secret.name // empty) ] | index("newsecret") != null)
  | .metadata.name' | head -1)

if [ -z "$POD" ]; then
  echo "❌ No running Pod in namespace '$NS' mounts the secret 'newsecret'"
  exit 1
fi

# the volume must really be mounted by a container
if ! kubectl get pod "$POD" -n "$NS" -o json | jq -e '
    ([.spec.volumes[]? | select(.secret.secretName == "newsecret" or ([.projected.sources[]?.secret.name] | index("newsecret") != null)) | .name]) as $v
    | [.spec.containers[].volumeMounts[]? | select(.name as $n | $v | index($n) != null)] | length > 0' >/dev/null; then
  echo "❌ Pod '$POD' declares the volume but no container mounts it"
  exit 1
fi

echo "✅ Pod '$POD' mounts the secret 'newsecret'"
exit 0
