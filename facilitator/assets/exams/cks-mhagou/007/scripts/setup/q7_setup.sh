#!/bin/bash

# Setup for MHAGOU-007 Question 7: ICMP redirect parameters of node02 (the "default" settings for new
# interfaces). The kernel default is 1 (accept / send) and no file sets them. The original live values
# are stored in /var/tmp/.ckx-sysctl-orig so that the node restore puts them back; the files
# the candidate adds under /etc/sysctl.d are removed by the checkpoint restore.

source "$(dirname "$0")/../lib/wait-cluster.sh"
source "$(dirname "$0")/../lib/nodes.sh"

ssh -o StrictHostKeyChecking=no node02 'bash -s' <<'EOF'
set -e
: > /var/tmp/.ckx-sysctl-orig
for k in net.ipv4.conf.default.accept_redirects net.ipv4.conf.default.send_redirects; do
  echo "$k=$(sysctl -n $k)" >> /var/tmp/.ckx-sysctl-orig
  sysctl -q -w "$k=1"
done
EOF

echo "Setup completed for MHAGOU-007 Question 7 ($NODE02: default accept/send redirects = 1)"
exit 0
