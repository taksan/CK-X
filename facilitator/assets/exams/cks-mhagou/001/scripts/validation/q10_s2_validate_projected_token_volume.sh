#!/bin/bash
# Item: immutable-pod runs with vault-sa and mounts the token through an explicit projected volume
# (serviceAccountToken source) in /var/run/secrets/kubernetes.io/serviceaccount

NS="vault-lab"
J=$(kubectl get pod immutable-pod -n "$NS" -o json 2>/dev/null)
[ -n "$J" ] || { echo "❌ Pod 'immutable-pod' not found in namespace '$NS' (it has to be re-created: a Pod spec cannot be edited in place)"; exit 1; }

[ "$(echo "$J" | jq -r '.spec.serviceAccountName')" = "vault-sa" ] || { echo "❌ immutable-pod does not use vault-sa"; exit 1; }
[ "$(echo "$J" | jq -r '.metadata.deletionTimestamp // ""')" = "" ] || { echo "❌ immutable-pod is being deleted"; exit 1; }

# the volume injected by the API server for the automounted token (kube-api-access-*) does not count
VOL=$(echo "$J" | jq -r '[.spec.volumes[]? | select((.name | startswith("kube-api-access-") | not) and any(.projected.sources[]?; has("serviceAccountToken")))][0].name // empty')
[ -n "$VOL" ] || { echo "❌ The Pod has no projected volume of its own with a serviceAccountToken source"; exit 1; }

DIR=/var/run/secrets/kubernetes.io/serviceaccount
if ! echo "$J" | jq -e --arg v "$VOL" --arg d "$DIR" 'any(.spec.containers[].volumeMounts[]?; .name == $v and (.mountPath == $d or .mountPath == ($d + "/token")))' >/dev/null; then
  echo "❌ The projected volume '$VOL' is not mounted at $DIR (the token file must be $DIR/token)"
  exit 1
fi

[ "$(echo "$J" | jq -r '.status.phase')" = "Running" ] && echo "$J" | jq -e 'all(.status.containerStatuses[]?; .ready == true)' >/dev/null || { echo "❌ immutable-pod is not Running and Ready"; exit 1; }

echo "✅ immutable-pod mounts the token of vault-sa through a projected volume"
exit 0
