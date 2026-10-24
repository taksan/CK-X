#!/bin/bash
# Nothing else is captured: the processes of the other containers of the node (kube-proxy,
# metallb, cilium...) must not be in the file. The nginx container itself may show sh, sleep, nginx
# and its spawned process

source "$(dirname "$0")/../lib/capture-q5.sh"
load_capture || exit 1

FOREIGN=$(echo "$NAMES" | grep -vxE 'uname|hostname|sleep|sh|nginx' | sort | uniq -c | sort -rn | head -3 | tr '\n' ';')
[ -z "$FOREIGN" ] || { echo "❌ Processes of other containers are in the file: $FOREIGN restrict the capture to the selected container"; exit 1; }

echo "✅ Only the processes of the selected container are captured"
exit 0
