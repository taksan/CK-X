#!/bin/bash
# The result file on k8s-api-server holds the right SHA-256 record for kubelet

source "$(dirname "$0")/../lib/q5-lib.sh"
check_record kubelet || exit 1

echo "✅ The record for kubelet has the checksum of the installed binary"
exit 0
