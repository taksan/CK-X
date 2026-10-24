#!/bin/bash
# Validate backend-qa cannot read secrets (however it gets there) and that the access of the
# other ServiceAccount to ConfigMaps was not thrown away

NS="qa"
SA="system:serviceaccount:$NS:backend-qa"
BOT="system:serviceaccount:$NS:ci-bot"

kubectl get serviceaccount backend-qa -n "$NS" >/dev/null 2>&1 || { echo "❌ ServiceAccount 'backend-qa' not found"; exit 1; }

for verb in get list watch; do
  if [ "$(kubectl auth can-i "$verb" secrets -n "$NS" --as "$SA" 2>/dev/null)" = "yes" ]; then
    echo "❌ backend-qa can still $verb secrets in '$NS'"
    exit 1
  fi
done

if [ "$(kubectl auth can-i get configmaps -n "$NS" --as "$BOT" 2>/dev/null)" != "yes" ]; then
  echo "❌ ci-bot lost its access to ConfigMaps: only the access to secrets had to be removed"
  exit 1
fi

echo "✅ backend-qa cannot read secrets and ci-bot can still read ConfigMaps"
exit 0
