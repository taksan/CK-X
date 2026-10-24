#!/bin/bash
# The Pods labelled app=backend of ANY namespace can reach nginx-pod (the Pod api-client of
# moon-ext-a). Credited only when the policy is effective.

source "$(dirname "$0")/../lib/netpol-probe.sh"
wait_enforced
reach moon-ext-b web-client && { echo "❌ The policy is not effective yet: a Pod of another namespace still reaches nginx-pod"; exit 1; }

reach moon-ext-a api-client || { echo "❌ The Pod api-client (label app=backend, namespace moon-ext-a) cannot reach nginx-pod: the label must match in any namespace"; exit 1; }

echo "✅ Pods labelled app=backend of other namespaces can reach nginx-pod"
exit 0
