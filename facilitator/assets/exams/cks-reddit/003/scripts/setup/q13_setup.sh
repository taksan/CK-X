#!/bin/bash

# Setup for CKS-003 Question 13: a service listening on port 389 on node02.
#
# A copy of netcat named "ldapd" listens on 389 and keeps /var/log/ldapd.log open. Its
# executable is a private copy (/usr/local/sbin/ldapd), so deleting it is safe. The
# candidate works on node02 (ssh node02).

NODE="node02"

ssh -o StrictHostKeyChecking=no "$NODE" 'bash -s' <<'EOF'
set -e
pkill -x ldapd 2>/dev/null || true
rm -f /usr/local/sbin/ldapd /var/log/ldapd.log
cp /usr/bin/nc /usr/local/sbin/ldapd
nohup /usr/local/sbin/ldapd -lk 389 >>/var/log/ldapd.log 2>&1 &
mkdir -p /tmp/exam/cks-003-q13
rm -f /tmp/exam/cks-003-q13/*
sleep 1
ss -ltn | grep -q ':389 '
EOF

if [ $? -ne 0 ]; then
  echo "Failed to start the service on $NODE"
  exit 1
fi

echo "Setup completed for CKS-003 Question 13 (service on port 389 of $NODE)"
exit 0
