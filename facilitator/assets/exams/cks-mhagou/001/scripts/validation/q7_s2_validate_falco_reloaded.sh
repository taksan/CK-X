#!/bin/bash
# Item: the Falco service of node01 was (re)started after the rules file was written and runs stably
source "$(dirname "$0")/../lib/nodes.sh"

R=$(ssh -o StrictHostKeyChecking=no node01 'bash -s' <<'EOF'
FILE=/etc/falco/falco_rules.local.yaml
[ -f "$FILE" ] || { echo "nofile"; exit 0; }
# credited only once the custom rule is in the file (the service is restarted by the setup of the exam)
grep -q 'SHADOW READ' "$FILE" || { echo "norule"; exit 0; }
S=falco-modern-bpf
systemctl is-active --quiet $S || { echo "inactive"; exit 0; }
START=$(date -d "$(systemctl show -p ActiveEnterTimestamp --value $S)" +%s 2>/dev/null)
MTIME=$(stat -c %Y "$FILE")
NOW=$(date +%s)
if [ "$START" -lt "$MTIME" ]; then echo "stale"; exit 0; fi
if [ $((NOW - START)) -lt 12 ]; then echo "starting"; exit 0; fi
echo "ok"
EOF
)
case "$R" in
  nofile)   echo "❌ /etc/falco/falco_rules.local.yaml does not exist on $NODE01"; exit 1 ;;
  norule)   echo "❌ /etc/falco/falco_rules.local.yaml does not contain the 'SHADOW READ' rule yet"; exit 1 ;;
  inactive) echo "❌ The Falco service (falco-modern-bpf) of $NODE01 is not running (an invalid rules file stops it)"; exit 1 ;;
  stale)    echo "❌ Falco was not restarted after /etc/falco/falco_rules.local.yaml was written (systemctl restart falco-modern-bpf)"; exit 1 ;;
  starting) sleep 14 ;;
  ok) ;;
  *) echo "❌ Unable to check the Falco service of $NODE01"; exit 1 ;;
esac

ssh -o StrictHostKeyChecking=no node01 'systemctl is-active --quiet falco-modern-bpf' || { echo "❌ The Falco service of $NODE01 is not running"; exit 1; }
echo "✅ Falco runs on $NODE01 with the rules loaded after the last change"
exit 0
