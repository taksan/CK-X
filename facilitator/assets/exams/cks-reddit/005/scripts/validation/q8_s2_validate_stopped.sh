#!/bin/bash
# Validate on node02: the suspicious process is stopped and the node stays healthy (kubelet running)

source "$(dirname "$0")/../lib/nodes.sh"

RESULT=$(ssh -o StrictHostKeyChecking=no node02 bash -s <<'EOF2'
RUNNING=no; pgrep -f '/var/tmp/\.ckx-sysd/dbus-helper' >/dev/null && RUNNING=yes
KUBELET=no; systemctl is-active --quiet kubelet && KUBELET=yes
echo "$RUNNING $KUBELET"
EOF2
)
set -- $RESULT
[ "$1" = "no" ] || { echo "❌ The suspicious process is still running on $NODE02"; exit 1; }
[ "$2" = "yes" ] || { echo "❌ The kubelet of $NODE02 is not running anymore"; exit 1; }

echo "✅ The suspicious process is stopped on $NODE02"
exit 0
