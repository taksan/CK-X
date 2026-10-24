#!/bin/bash
# Validate the executable of the service was removed from node02

NODE="node02"

if ssh -o StrictHostKeyChecking=no "$NODE" "[ -e /usr/local/sbin/ldapd ]" 2>/dev/null; then
  echo "❌ The executable of the service (/usr/local/sbin/ldapd) still exists on $NODE"
  exit 1
fi

# the system must be intact: the netcat everybody else uses must still be there
if ! ssh -o StrictHostKeyChecking=no "$NODE" "[ -x /usr/bin/nc.openbsd ]" 2>/dev/null; then
  echo "❌ A system binary was removed instead of the service executable"
  exit 1
fi

echo "✅ The executable of the service was removed"
exit 0
