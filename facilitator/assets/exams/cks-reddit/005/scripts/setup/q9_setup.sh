#!/bin/bash

# Setup for CKS-005 Question 9: audit log forensics. Files only (jumphost), no namespace.
# A synthetic API server audit log (JSON lines, ~2000 events) with the story hidden in the noise:
# one user deleted the Secret payment-gateway-key in the namespace billing successfully; others
# tried (403), only read it or deleted another Secret. The deleter has its own source IP.

source "$(dirname "$0")/../lib/wait-cluster.sh"

DIR="/tmp/exam/cks-005-q9"
mkdir -p "${DIR:?}"
rm -f "${DIR:?}"/* "${DIR:?}"/.expected

USERS=(alice bob carol dave erin frank grace heidi)
mapfile -t SHUF < <(printf '%s\n' "${USERS[@]}" | shuf)
ACTOR="${SHUF[0]}"; DENIED="${SHUF[1]}"; READER="${SHUF[2]}"; OTHER_DELETER="${SHUF[3]}"
DECOY_DELETED=$(printf '%s\n' invoice-signing-key smtp-credentials tax-api-token ledger-tls | shuf -n 1)
ACTOR_IP="10.30.$(shuf -i 1-250 -n 1).$(shuf -i 10-250 -n 1)"

awk -v actor="$ACTOR" -v denied="$DENIED" -v reader="$READER" -v other="$OTHER_DELETER" \
    -v aip="$ACTOR_IP" -v decoy="$DECOY_DELETED" -v seed="$RANDOM" '
function ev(ts, user, ip, verb, res, ns, name, code,    uri) {
  uri = "/api/v1/namespaces/" ns "/" res (name != "" ? "/" name : "")
  printf "{\"kind\":\"Event\",\"apiVersion\":\"audit.k8s.io/v1\",\"level\":\"Metadata\",\"auditID\":\"%08x-%04x-4%03x-a%03x-%012x\",\"stage\":\"ResponseComplete\",\"requestURI\":\"%s\",\"verb\":\"%s\",\"user\":{\"username\":\"%s\",\"groups\":[\"system:authenticated\"]},\"sourceIPs\":[\"%s\"],\"objectRef\":{\"resource\":\"%s\",\"namespace\":\"%s\",\"name\":\"%s\",\"apiVersion\":\"v1\"},\"responseStatus\":{\"code\":%d},\"requestReceivedTimestamp\":\"%s\",\"stageTimestamp\":\"%s\"}\n", int(rand()*4294967295), int(rand()*65535), int(rand()*4095), int(rand()*4095), int(rand()*1e12), uri, verb, user, ip, res, ns, name, code, ts, ts
}
function ts(n) { return sprintf("2026-10-14T%02d:%02d:%02d.%06dZ", 8 + int(n/3600), int((n%3600)/60), n%60, int(rand()*999999)) }
function ip(u) { if (u == actor) return aip; return "10.20." (length(u) % 7) "." (10 + (length(u) * 13) % 200) }
BEGIN {
  srand(seed)
  split("alice bob carol dave erin frank grace heidi", U, " ")
  split("pods configmaps services endpoints serviceaccounts events", R, " ")
  split("get list watch create update patch", V, " ")
  split("default payments shipping billing inventory monitoring", N, " ")
  total = 2000; t = 0
  special_at = 1400
  for (i = 1; i <= total; i++) {
    t += 1 + int(rand() * 8)
    if (i == special_at - 150) { ev(ts(t), reader, ip(reader), "get", "secrets", "billing", "payment-gateway-key", 200) }
    else if (i == special_at - 100) { ev(ts(t), denied, ip(denied), "delete", "secrets", "billing", "payment-gateway-key", 403) }
    else if (i == special_at - 50) { ev(ts(t), other, ip(other), "delete", "secrets", "billing", decoy, 200) }
    else if (i == special_at) { ev(ts(t), actor, ip(actor), "delete", "secrets", "billing", "payment-gateway-key", 200) }
    else {
      u = U[1 + int(rand() * 8)]; r = R[1 + int(rand() * 6)]; v = V[1 + int(rand() * 6)]; n = N[1 + int(rand() * 6)]
      nm = (v == "list" || v == "watch" || v == "create") ? "" : r "-" int(rand() * 40)
      ev(ts(t), u, ip(u), v, r, n, nm, 200)
    }
  }
}' > "$DIR/audit.log"

cat > "$DIR/.expected" <<EOF
EXPECTED_ACTOR=$ACTOR
EXPECTED_IP=$ACTOR_IP
EOF

echo "Setup completed for CKS-005 Question 9 (audit log in $DIR/audit.log)"
exit 0
