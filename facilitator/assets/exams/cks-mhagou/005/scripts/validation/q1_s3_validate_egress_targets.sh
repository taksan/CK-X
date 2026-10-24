#!/bin/bash
# Egress of the backends: the database of network-security on 5432 is allowed; the frontend and
# other of network-security and the database of the peer namespace are denied

source "$(dirname "$0")/../lib/q1-lib.sh"
init_q1 || exit 1

FAIL=0
for b in backend-a backend-b; do
  expect_blocked "Egress of $b" "$NS" "$b" "$IP_FR" 8080 || FAIL=1
  expect_blocked "Egress of $b" "$NS" "$b" "$IP_OT" 8080 || FAIL=1
  expect_blocked "Egress of $b" "$NS" "$b" "$IP_PDB" 5432 || FAIL=1
done
for b in backend-a backend-b; do
  expect_ok "Egress of $b" "$NS" "$b" "$IP_DB" 5432 || FAIL=1
done
[ "$FAIL" -eq 0 ] || exit 1

echo "✅ The backends reach only the database of network-security (frontend, other and the peer database are denied)"
exit 0
