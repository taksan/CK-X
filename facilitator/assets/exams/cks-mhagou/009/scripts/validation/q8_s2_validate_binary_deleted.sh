#!/bin/bash
# Item: the executable of the service was deleted (and a system binary was not)

source "$(dirname "$0")/../lib/nodes.sh"

NODE="$NODE01"

if ssh -o StrictHostKeyChecking=no "$NODE" "[ -e /usr/local/sbin/ldapd ]" 2>/dev/null; then
  echo "❌ The executable of the service (/usr/local/sbin/ldapd) still exists on $NODE"
  exit 1
fi
ssh -o StrictHostKeyChecking=no "$NODE" "[ -x /usr/bin/nc.openbsd ] || [ -x /usr/bin/nc ]" 2>/dev/null \
  || { echo "❌ A system binary was removed instead of the executable of the service"; exit 1; }

echo "✅ The executable of the service was deleted"
exit 0
