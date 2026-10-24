#!/bin/bash
# Item: ci-bot keeps get/list/watch/create/update/delete on pods, services and configmaps in ci-cd.
# Credited only when the escalation is closed (otherwise the starting state would score).

source "$(dirname "$0")/../lib/rbac-q4.sh"
escalation_closed || { echo "❌ The escalation is still possible (see the two items about cluster-admin and admin): nothing to credit yet"; exit 1; }

for res in pods services configmaps; do
  for verb in get list watch create update delete; do
    [ "$(can_i "$verb" "$res" -n "$Q4_NS")" = "yes" ] || { echo "❌ ci-bot lost '$verb $res' in $Q4_NS: its current permissions had to be kept"; exit 1; }
  done
done

echo "✅ ci-bot keeps its permissions on pods, services and configmaps in ci-cd"
exit 0
