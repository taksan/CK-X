#!/bin/bash
# The Pods of the namespace hello can reach nginx-pod. Credited only when the policy is effective
# (a Pod of another namespace is blocked), otherwise "no policy" would be a free mark.

source "$(dirname "$0")/../lib/netpol-probe.sh"
wait_enforced
reach moon-ext-b web-client && { echo "❌ The policy is not effective yet: a Pod of another namespace still reaches nginx-pod"; exit 1; }

reach hello peer || { echo "❌ The Pod peer of the namespace hello cannot reach nginx-pod on port 80"; exit 1; }

echo "✅ Pods of the namespace hello can reach nginx-pod"
exit 0
