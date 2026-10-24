#!/bin/bash
# Item: the daemon runs with the group root: its unix socket belongs to the group root (credited only when the service runs)

source "$(dirname "$0")/../lib/dockerd-lab.sh"
source "$(dirname "$0")/../lib/nodes.sh"
dockerd_lab_state "" || { echo "❌ Unable to read the state of dockerd-lab on $NODE01"; exit 1; }
[ "$DL_RUN" = "yes" ] || { echo "❌ dockerd-lab.service does not run stably on $NODE01 (check the configuration: journalctl -u dockerd-lab)"; exit 1; }
[ "$DL_GROUP" = "root" ] || { echo "❌ The socket /run/dockerd-lab.sock of $NODE01 belongs to the group '${DL_GROUP:-none}', expected root"; exit 1; }

echo "✅ dockerd-lab runs with the group root (socket group root)"
exit 0
