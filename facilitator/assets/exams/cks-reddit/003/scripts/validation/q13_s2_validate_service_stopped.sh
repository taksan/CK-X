#!/bin/bash
# Validate nothing listens on port 389 on node02 any more

NODE="node02"

if ssh -o StrictHostKeyChecking=no "$NODE" "ss -ltn | grep -q ':389 '" 2>/dev/null; then
  echo "❌ A service is still listening on port 389 of $NODE"
  exit 1
fi

echo "✅ Nothing listens on port 389 of $NODE"
exit 0
