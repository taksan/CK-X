#!/bin/bash
# Ingress of the backends: frontend reaches TCP 8080 only; the other ports are denied

source "$(dirname "$0")/../lib/q1-lib.sh"
init_q1 || exit 1

FAIL=0
for spec in "backend-a $IP_BA" "backend-b $IP_BB"; do
  read -r name ip <<< "$spec"
  for port in 8081 5432 5433; do
    expect_blocked "Ingress to $name" "$NS" frontend "$ip" "$port" || FAIL=1
  done
  expect_ok "Ingress to $name" "$NS" frontend "$ip" 8080 || FAIL=1
done
[ "$FAIL" -eq 0 ] || exit 1

echo "✅ The backends only accept TCP 8080 from the frontend (8081, 5432 and 5433 are denied)"
exit 0
