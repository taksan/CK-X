#!/bin/bash
# kubectl and kubelet were not modified or replaced (credited together with the two records, otherwise
# this check would pass before any work is done)

source "$(dirname "$0")/../lib/q5-lib.sh"
check_record kubectl || exit 1
check_record kubelet || exit 1
binaries_untouched || { echo "❌ kubectl or kubelet on $CONTROL_PLANE changed since the exam started: the binaries must not be modified or replaced"; exit 1; }

echo "✅ Both records are right and the binaries were not modified"
exit 0
