#!/bin/bash

# Setup for CKS-005 Question 8: a suspicious process on node02 that calls home.
# The process keeps trying to connect to a random address (TEST-NET-3, RFC 5737, never routed).
# Its address is stored in /var/tmp/.ckx-q8-state on node02, which the node restore uses to
# remove the firewall rule / route the candidate adds. Namespace: none (host level question).

source "$(dirname "$0")/../lib/wait-cluster.sh"
source "$(dirname "$0")/../lib/nodes.sh"

DIR="/tmp/exam/cks-005-q8"
mkdir -p "${DIR:?}"
rm -f "${DIR:?}"/*

IP="203.0.113.$(shuf -i 10-250 -n 1)"
PORT=$(shuf -i 30000-39999 -n 1)

ssh -o StrictHostKeyChecking=no node02 "IP=$IP PORT=$PORT bash -s" <<'EOF'
pkill -f '/var/tmp/\.ckx-' 2>/dev/null || true
mkdir -p /var/tmp/.ckx-sysd
cat > /var/tmp/.ckx-sysd/dbus-helper <<SCRIPT
#!/bin/bash
while true; do
  timeout 3 bash -c 'exec 3<>/dev/tcp/$IP/$PORT' 2>/dev/null
  sleep 2
done
SCRIPT
chmod +x /var/tmp/.ckx-sysd/dbus-helper
cat > /var/tmp/.ckx-q8-state <<STATE
Q8_IP=$IP
Q8_PORT=$PORT
STATE
nohup setsid /var/tmp/.ckx-sysd/dbus-helper >/dev/null 2>&1 < /dev/null &
EOF

echo "Setup completed for CKS-005 Question 8 (suspicious process on $NODE02, findings directory $DIR)"
exit 0
