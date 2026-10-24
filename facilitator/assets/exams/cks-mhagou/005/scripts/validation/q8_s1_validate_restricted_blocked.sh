#!/bin/bash
# Behaviour: restricted-pod (role=restricted) cannot reach the Kubernetes API (Service address and real endpoint)

source "$(dirname "$0")/../lib/q8-lib.sh"
init_q8 || exit 1
restricted_blocked || { echo "❌ $BLOCK_REASON"; exit 1; }

echo "✅ restricted-pod cannot reach the Kubernetes API"
exit 0
