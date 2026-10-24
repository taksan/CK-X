#!/bin/bash
# Validate Pod app-pod (nginx) mounts app-config-secret at /etc/app-config, read-only, with mode 0400

NS="app"

JSON=$(kubectl get pod app-pod -n "$NS" -o json 2>/dev/null)
[ -n "$JSON" ] || { echo "❌ Pod 'app-pod' not found in namespace '$NS'"; exit 1; }

echo "$JSON" | jq -e '[.spec.containers[].image] | any(startswith("nginx"))' >/dev/null || { echo "❌ Pod 'app-pod' does not use the nginx image"; exit 1; }

VOL=$(echo "$JSON" | jq -r '[.spec.volumes[]? | select(.secret.secretName == "app-config-secret")][0] // empty')
[ -n "$VOL" ] || { echo "❌ Pod 'app-pod' does not mount the secret 'app-config-secret'"; exit 1; }
NAME=$(echo "$VOL" | jq -r '.name')

if ! echo "$JSON" | jq -e --arg n "$NAME" '[.spec.containers[].volumeMounts[]? | select(.name == $n and .mountPath == "/etc/app-config" and .readOnly == true)] | length > 0' >/dev/null; then
  echo "❌ The secret must be mounted read-only at /etc/app-config"
  exit 1
fi

if [ "$(echo "$VOL" | jq -r '.secret.defaultMode // 420')" != "256" ]; then
  echo "❌ The files of the secret volume must have the mode 0400 (defaultMode: 256)"
  exit 1
fi

[ "$(echo "$JSON" | jq -r '.status.phase')" = "Running" ] || { echo "❌ Pod 'app-pod' is not running"; exit 1; }

MODE=$(kubectl exec -n "$NS" app-pod -- stat -L -c %a /etc/app-config/APP_USER 2>/dev/null)
if [ "$MODE" != "400" ]; then
  echo "❌ /etc/app-config/APP_USER has the mode '$MODE' in the Pod, expected 400"
  exit 1
fi

echo "✅ app-pod mounts the secret read-only at /etc/app-config with mode 0400"
exit 0
