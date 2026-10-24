#!/bin/bash
# Validate the dmesg output was captured inside the gVisor sandbox (not on the host kernel)

FILE="${Q7_FILE:-/tmp/exam/cks-003-q7/untrusted-dmesg.txt}"

if [ ! -s "$FILE" ]; then
  echo "❌ '$FILE' does not exist or is empty"
  exit 1
fi

if ! grep -q "Starting gVisor" "$FILE"; then
  echo "❌ The file does not contain the dmesg of a gVisor sandbox (run dmesg inside the Pod 'untrusted')"
  exit 1
fi

echo "✅ The file contains the dmesg output of the gVisor sandbox"
exit 0
