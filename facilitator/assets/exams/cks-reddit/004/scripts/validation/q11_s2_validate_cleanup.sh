#!/bin/bash
# Validate unused ServiceAccounts were removed and the used ones were kept

NS="web-team"

SAS=$(kubectl get sa -n "$NS" -o jsonpath='{.items[*].metadata.name}' 2>/dev/null)
[ -n "$SAS" ] || { echo "❌ Unable to list ServiceAccounts in namespace '$NS'"; exit 1; }

for sa in stale-account old-bot; do
  if echo " $SAS " | grep -q " $sa "; then
    echo "❌ The unused ServiceAccount '$sa' still exists"
    exit 1
  fi
done

for sa in default reporter-sa frontend-sa; do
  if ! echo " $SAS " | grep -q " $sa "; then
    echo "❌ ServiceAccount '$sa' was deleted but it is in use / required"
    exit 1
  fi
done

[ "$(kubectl get pod reporter -n "$NS" -o jsonpath='{.status.phase}' 2>/dev/null)" = "Running" ] || { echo "❌ Pod 'reporter' is not running"; exit 1; }

echo "✅ Unused ServiceAccounts removed; used ones kept"
exit 0
