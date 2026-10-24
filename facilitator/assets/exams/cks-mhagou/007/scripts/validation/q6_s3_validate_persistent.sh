#!/bin/bash
# Item: the configuration is persistent: after a restart of the service (with a systemd reload) the daemon runs
# stably with the group root and without TCP

source "$(dirname "$0")/../lib/dockerd-lab.sh"
source "$(dirname "$0")/../lib/nodes.sh"
dockerd_lab_state restart || { echo "❌ Unable to read the state of dockerd-lab on $NODE01"; exit 1; }
[ "$DL_RUN" = "yes" ] || { echo "❌ dockerd-lab.service does not start (and stay up) again after a restart (journalctl -u dockerd-lab)"; exit 1; }
[ "$DL_GROUP" = "root" ] || { echo "❌ After a restart the socket group is '$DL_GROUP', expected root: the change is not persistent"; exit 1; }
[ "$DL_TCP" = "0" ] || { echo "❌ After a restart $NODE01 listens on TCP 2375 again: the change is not persistent"; exit 1; }

echo "✅ After a restart dockerd-lab still runs with the group root and without TCP"
exit 0
