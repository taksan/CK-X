#!/bin/bash
# The result file on k8s-api-server holds the right SHA-256 record for kubectl

source "$(dirname "$0")/../lib/q5-lib.sh"
check_record kubectl || exit 1

echo "✅ The record for kubectl has the checksum of the installed binary"
exit 0
