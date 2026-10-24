#!/bin/bash
# Egress of the backends to the database: TCP 5432 only

source "$(dirname "$0")/../lib/q1-lib.sh"
init_q1 || exit 1

FAIL=0
for b in backend-a backend-b; do
  for port in 5433 8080 8081; do
    expect_blocked "Egress of $b" "$NS" "$b" "$IP_DB" "$port" || FAIL=1
  done
  expect_ok "Egress of $b" "$NS" "$b" "$IP_DB" 5432 || FAIL=1
done
[ "$FAIL" -eq 0 ] || exit 1

echo "✅ The backends reach the database on TCP 5432 only (5433, 8080 and 8081 are denied)"
exit 0
