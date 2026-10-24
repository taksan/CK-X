#!/bin/bash
# Item: the database Pods can only send DNS (UDP and TCP 53) to the cluster DNS Pods of kube-system

source "$(dirname "$0")/../lib/cilium-probe.sh"
cilium_fixtures_ready || exit 1
OUT=$(pod_ip outside-lab cks-outsider)
mapfile -t DNS < <(kubectl -n kube-system get pods -l k8s-app=kube-dns -o jsonpath='{range .items[*]}{.status.podIP}{"\n"}{end}')
[ "${#DNS[@]}" -gt 0 ] || { echo "❌ No cluster DNS Pod found"; exit 1; }

for pod in cks-db cks-db-peer; do
  for i in 1 2 3 4 5 6; do denied data-tier $pod "$OUT" 3306 && break; sleep 3; done
  for port in 3306 8080 53; do
    denied data-tier $pod "$OUT" $port || { echo "❌ $pod can open TCP connections to a non-DNS endpoint on port $port: only DNS may leave the database Pods"; exit 1; }
  done
  denied data-tier $pod "$OUT" 53 udp || { echo "❌ $pod can send UDP 53 to a non-DNS endpoint"; exit 1; }
  for dns in "${DNS[@]}"; do
    allowed "" data-tier $pod "$dns" 53 dns-udp || { echo "❌ $pod cannot send DNS (UDP 53) to the cluster DNS Pod $dns"; exit 1; }
    allowed "" data-tier $pod "$dns" 53 dns-tcp || { echo "❌ $pod cannot send DNS (TCP 53) to the cluster DNS Pod $dns"; exit 1; }
  done
done

echo "✅ The database Pods can only reach the cluster DNS on UDP and TCP 53"
exit 0
