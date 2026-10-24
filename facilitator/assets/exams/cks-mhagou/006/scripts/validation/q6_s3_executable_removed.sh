#!/bin/bash
# The executable of the identified process was deleted; the rest of the system is intact (the
# process itself does not have to be stopped)

source "$(dirname "$0")/../lib/nodes.sh"

NODE="$NODE01"

if ssh -o StrictHostKeyChecking=no "$NODE" "[ -e /usr/local/sbin/ldapd ]" 2>/dev/null; then
  echo "❌ The executable of the process on port 389 (/usr/local/sbin/ldapd) still exists on $NODE"
  exit 1
fi
if ! ssh -o StrictHostKeyChecking=no "$NODE" "[ -x /usr/bin/nc.openbsd ] && [ -d /var/lib/ldapd-data ] && [ -e /var/lib/ldapd-data/records.dat ]" 2>/dev/null; then
  echo "❌ Something else was removed instead of only the executable of the service (a system binary or the data files)"
  exit 1
fi

echo "✅ The executable of the service was removed and nothing else"
exit 0
