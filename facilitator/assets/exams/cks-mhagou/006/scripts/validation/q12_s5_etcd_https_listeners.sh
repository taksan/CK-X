#!/bin/bash
# Every etcd client listener (and the advertised client URLs) uses https and nothing listens in plain
# HTTP on the extra port

source "$(dirname "$0")/../lib/tls-q12.sh"
M=$(manifest_cmd etcd)
[ -n "$M" ] || { echo "❌ Unable to read the etcd manifest on the control plane"; exit 1; }

L=$(echo "$M" | jq -r '[.[] | select(startswith("--listen-client-urls="))] | first // empty | sub("^--listen-client-urls="; "")')
[ -n "$L" ] || { echo "❌ etcd has no --listen-client-urls flag"; exit 1; }
for u in $(echo "$L" | tr ',' ' '); do
  case "$u" in https://*) ;; *) echo "❌ The etcd client listener $u is not https"; exit 1 ;; esac
done
A=$(echo "$M" | jq -r '[.[] | select(startswith("--advertise-client-urls="))] | first // empty | sub("^--advertise-client-urls="; "")')
for u in $(echo "$A" | tr ',' ' '); do
  case "$u" in https://*) ;; *) echo "❌ The advertised etcd client URL $u is not https"; exit 1 ;; esac
done

ssh -o StrictHostKeyChecking=no "$CP" "ss -ltn | grep -q ':2399 '" 2>/dev/null && { echo "❌ A plain-HTTP etcd client listener still listens on port 2399 (the running etcd was not restarted?)"; exit 1; }

echo "✅ All etcd client listeners use https"
exit 0
