#!/bin/bash

# Setup for MHagou-006 Question 6: a suspicious service listening on port 389 of node01.
#
# A private copy of netcat named "ldapd" listens on 389; it was started with two data files open in
# addition to its log. Its executable is /usr/local/sbin/ldapd (a private copy, deleting it is safe;
# the node restore also removes it). The expected open files are recorded in /var/tmp/.ckx-q6-state on
# the node (removed by the node restore). The candidate works on node01 (ssh node01).

source "$(dirname "$0")/../lib/nodes.sh"

NODE="$NODE01"

ssh -o StrictHostKeyChecking=no "$NODE" 'bash -s' <<'EOF'
set -e
pkill -x ldapd 2>/dev/null || true
rm -rf /usr/local/sbin/ldapd /var/log/ldapd.log /var/lib/ldapd-data /var/tmp/.ckx-q6-state
mkdir -p /var/lib/ldapd-data /tmp/exam/mhagou-006-q6
rm -f /tmp/exam/mhagou-006-q6/*
echo "harmless exercise data" > /var/lib/ldapd-data/records.dat
echo "harmless exercise configuration" > /var/lib/ldapd-data/service.conf
cp /usr/bin/nc /usr/local/sbin/ldapd
nohup bash -c 'exec 7</var/lib/ldapd-data/records.dat 8</var/lib/ldapd-data/service.conf; exec /usr/local/sbin/ldapd -lk 389' >>/var/log/ldapd.log 2>&1 &
sleep 1
PID=$(pgrep -x ldapd | head -1)
[ -n "$PID" ]
ss -ltn | grep -q ':389 '
INODE=$(ls -l /proc/$PID/fd | grep -o 'socket:\[[0-9]*\]' | head -1 | tr -dc '0-9')
cat > /var/tmp/.ckx-q6-state <<STATE
Q6_PID=$PID
Q6_SOCKET_INODE=$INODE
STATE
EOF

if [ $? -ne 0 ]; then
  echo "Failed to start the service on $NODE"
  exit 1
fi

echo "Setup completed for MHagou-006 Question 6 (service on port 389 of $NODE)"
exit 0
