#!/bin/bash

# Setup for MHagou CKS exam 9, Question 8: a service listening on port 389 of the first worker node.
# A copy of netcat named "ldapd" listens on 389 and keeps /var/log/ldapd.log open. Its executable is a
# private copy (/usr/local/sbin/ldapd), so deleting it is safe; the node restore removes leftovers.

source "$(dirname "$0")/../lib/nodes.sh"

NODE="$NODE01"
DIR="/tmp/exam/mhagou-009-q8"

ssh -o StrictHostKeyChecking=no "$NODE" "DIR=$DIR bash -s" <<'EOF'
set -e
pkill -x ldapd 2>/dev/null || true
rm -f /usr/local/sbin/ldapd /var/log/ldapd.log
cp /usr/bin/nc /usr/local/sbin/ldapd
nohup /usr/local/sbin/ldapd -lk 389 >>/var/log/ldapd.log 2>&1 &
mkdir -p "$DIR"
rm -f "${DIR:?}"/*
sleep 1
ss -ltn | grep -q ':389 '
EOF

if [ $? -ne 0 ]; then
  echo "Failed to start the service on $NODE"
  exit 1
fi

echo "Setup completed for MHagou exam 9 Question 8 (service on port 389 of $NODE, output directory $DIR on $NODE)"
exit 0
