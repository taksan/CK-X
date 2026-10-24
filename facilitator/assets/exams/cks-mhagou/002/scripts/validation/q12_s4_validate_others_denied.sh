#!/bin/bash
# Everything else is denied: the neighbour of the namespace moon and a Pod of another namespace
# without the label. Credited only when at least one of the allowed sources works (a deny-all policy
# would otherwise earn this item without solving the task).

source "$(dirname "$0")/../lib/netpol-probe.sh"
wait_enforced

if ! reach hello peer && ! reach moon-ext-a api-client; then
  echo "❌ No allowed source (namespace hello, label app=backend) reaches nginx-pod: nothing to credit yet"
  exit 1
fi
reach moon-ext-b web-client && { echo "❌ A Pod of another namespace without the label app=backend (web-client) reaches nginx-pod"; exit 1; }
reach moon neighbor && { echo "❌ A Pod of the namespace moon itself (neighbor) reaches nginx-pod: only the listed sources may connect"; exit 1; }

echo "✅ Pods outside the allowed sources cannot reach nginx-pod"
exit 0
