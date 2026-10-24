#!/bin/bash
# Validate secret-readers.txt lists the ServiceAccounts of rbac-audit that can read secrets.
# It is compared with the facts of the cluster at the time of the exam start: reader-sa, batch-sa
# and ops-sa (fixed by the setup), whatever the candidate changed afterwards.

F="${Q2_FILE:-/tmp/exam/cks-005-q2/secret-readers.txt}"
[ -s "$F" ] || { echo "❌ $F does not exist or is empty"; exit 1; }

GOT=$(sed 's/[[:space:]]//g; /^$/d' "$F" | sort | tr '\n' ' ')
if [ "$GOT" != "batch-sa ops-sa reader-sa " ]; then
  echo "❌ The list is '$GOT': it must contain exactly the ServiceAccounts that could read Secrets (wildcard roles and built-in ClusterRoles count)"
  exit 1
fi

echo "✅ secret-readers.txt lists the ServiceAccounts that could read Secrets"
exit 0
