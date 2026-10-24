#!/bin/bash
# Item: the API server was restarted with the encryption configuration: the flag is in the manifest, the
# file is mounted into the container (hostPath volume of the file or of a parent directory), and the
# running API server is ready

source "$(dirname "$0")/../lib/apiserver.sh"

FILE=$(apiserver_flag encryption-provider-config)
[ -n "$FILE" ] || { echo "❌ kube-apiserver has no --encryption-provider-config flag in its manifest"; exit 1; }

V=$(apiserver_manifest_volumes)
if ! echo "$V" | jq -e --arg f "$FILE" '
    . as $all
    | [($all.mounts // [])[] | select(. as $m | $m.mountPath == $f or ($f | startswith($m.mountPath + "/"))) | .name] as $names
    | ($names | length) > 0
      and any(($all.volumes // [])[]; (.name as $n | $names | index($n) != null) and has("hostPath"))' >/dev/null 2>&1; then
  echo "❌ The file $FILE is not mounted into the kube-apiserver container (hostPath volume + volumeMount)"
  exit 1
fi

wait_api_ready 150 || { echo "❌ The API server is not ready (check the manifest and 'crictl logs' of the kube-apiserver container)"; exit 1; }
# the running container itself is checked on the control plane (the mirror Pod in the API can lag behind)
ARGS=$(ssh -o StrictHostKeyChecking=no "$APISERVER_NODE" 'bash -s' <<'EOF' 2>/dev/null
export CONTAINER_RUNTIME_ENDPOINT=unix:///run/containerd/containerd.sock
for id in $(crictl ps --name kube-apiserver --state running -q 2>/dev/null); do
  crictl inspect "$id" 2>/dev/null | jq -r '.info.runtimeSpec.process.args[]?'
done
EOF
)
echo "$ARGS" | grep -q -- "^--encryption-provider-config=" || { echo "❌ The running kube-apiserver container was not started with --encryption-provider-config (was the API server restarted after the change?)"; exit 1; }

echo "✅ The API server runs with $FILE mounted and is ready"
exit 0
