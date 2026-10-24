#!/bin/bash
# Ingress of backend-a and backend-b: only frontend of network-security may connect on 8080;
# database, other and the frontend of the other namespace are denied

source "$(dirname "$0")/../lib/q1-lib.sh"
init_q1 || exit 1

FAIL=0
for spec in "backend-a $IP_BA" "backend-b $IP_BB"; do
  read -r name ip <<< "$spec"
  expect_blocked "Ingress to $name" "$NS" database "$ip" 8080 || FAIL=1
  expect_blocked "Ingress to $name" "$NS" other "$ip" 8080 || FAIL=1
  expect_blocked "Ingress to $name" "$PEER" frontend "$ip" 8080 || FAIL=1
done
for spec in "backend-a $IP_BA" "backend-b $IP_BB"; do
  read -r name ip <<< "$spec"
  expect_ok "Ingress to $name" "$NS" frontend "$ip" 8080 || FAIL=1
done
[ "$FAIL" -eq 0 ] || exit 1

echo "✅ Only network-security/frontend reaches the backends on 8080; database, other and the peer frontend are denied"
exit 0
