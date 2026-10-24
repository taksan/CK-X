#!/bin/bash
# Item: the allowed backend reaches TCP 3306 only, not TCP 8080 (credited once the ingress scope is restricted)

source "$(dirname "$0")/../lib/cilium-probe.sh"
cilium_fixtures_ready || exit 1

for target in cks-db cks-db-peer; do
  DEST=$(pod_ip data-tier $target)
  for i in 1 2 3 4 5 6; do denied web-tier cks-frontend "$DEST" 3306 && break; sleep 3; done
  denied web-tier cks-frontend "$DEST" 3306 || { echo "❌ The ingress of the database Pods is not restricted yet, nothing to credit"; exit 1; }
  allowed "" web-tier cks-backend "$DEST" 3306 || { echo "❌ web-tier/cks-backend cannot reach $target on TCP 3306"; exit 1; }
  denied web-tier cks-backend "$DEST" 8080 || { echo "❌ web-tier/cks-backend can reach $target on TCP 8080: only TCP 3306 may be allowed"; exit 1; }
done

echo "✅ The backend reaches the database Pods on TCP 3306 only"
exit 0
