#!/bin/bash
# Item: the test Pod was not modified and /dev/mem was not created in it (credited once the rule fires)

source "$(dirname "$0")/../lib/falco-devmem.sh"
run_devmem_falco || exit 1
echo "$DEVMEM_JSON" | jq -e 'select(.rule == "devmem")' >/dev/null || { echo "❌ The rule devmem raised no alert, nothing to credit"; exit 1; }

J=$(kubectl get pod test-falco -n devmem-lab -o json 2>/dev/null)
[ -n "$J" ] || { echo "❌ Pod test-falco was deleted"; exit 1; }
[ "$(echo "$J" | jq -r '.status.containerStatuses[0].restartCount')" = "0" ] || { echo "❌ The container of test-falco was restarted"; exit 1; }
[ "$(echo "$J" | jq -r '.spec.containers[0].image')" = "busybox:1.36.1" ] || { echo "❌ The Pod test-falco was modified"; exit 1; }
kubectl exec -n devmem-lab test-falco -- sh -c 'test ! -e /dev/mem' >/dev/null 2>&1 || { echo "❌ /dev/mem exists in the container: it must not be created"; exit 1; }

echo "✅ The Pod test-falco is unchanged and has no /dev/mem"
exit 0
