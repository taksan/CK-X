#!/bin/bash

# Setup for MHagou-003 Question 3: a Falco rule for /dev/mem on node01.
# Namespace memory-watch is exclusive (the candidate's trigger Pod and the validators' probe live
# there). Falco runs as a service on node01 and reads /etc/falco/falco_rules.local.yaml (restored by
# the node checkpoint). Nothing else is prepared.

source "$(dirname "$0")/../lib/wait-cluster.sh"
source "$(dirname "$0")/../lib/nodes.sh"

ensure_namespace "memory-watch"
rm -f /tmp/ckx-mhagou003-q3-journal /tmp/ckx-mhagou003-q3-stamp

echo "Setup completed for MHagou-003 Question 3 (namespace 'memory-watch', Falco on ${NODE01})"
exit 0
