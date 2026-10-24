#!/bin/bash
# Item: only the Pods app=backend of web-tier reach the database Pods (3306); the frontend, a backend of another
# namespace and the Pods of the database namespace itself are denied

source "$(dirname "$0")/../lib/cilium-probe.sh"
cilium_fixtures_ready || exit 1
OUT=$(pod_ip outside-lab cks-outsider)

for target in cks-db cks-db-peer; do
  DEST=$(pod_ip data-tier $target)
  PEER=cks-db-peer; [ "$target" = "cks-db-peer" ] && PEER=cks-db
  # a first denial shows that the policy is enforced (it needs some seconds)
  for i in 1 2 3 4 5 6; do denied web-tier cks-frontend "$DEST" 3306 && break; sleep 3; done
  denied web-tier cks-frontend "$DEST" 3306 || { echo "❌ web-tier/cks-frontend can reach $target on TCP 3306"; exit 1; }
  allowed "" web-tier cks-backend "$DEST" 3306 || { echo "❌ web-tier/cks-backend (app=backend) cannot reach $target on TCP 3306"; exit 1; }
  denied outside-lab cks-outsider "$DEST" 3306 || { echo "❌ A Pod with app=backend in another namespace can reach $target on TCP 3306: the policy must name the namespace web-tier too"; exit 1; }
  denied data-tier $PEER "$DEST" 3306 || { echo "❌ A Pod of the database namespace ($PEER) can reach $target on TCP 3306"; exit 1; }
done

echo "✅ Only app=backend of web-tier reaches the database Pods"
exit 0
