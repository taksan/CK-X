#!/bin/bash
# Item: /etc/falco/falco_rules.local.yaml is valid, loads with the default rules and defines the rule devmem
source "$(dirname "$0")/../lib/nodes.sh"

R=$(ssh -o StrictHostKeyChecking=no node01 'bash -s' <<'EOF'
yq '.[] | select(.rule == "devmem") | .rule' /etc/falco/falco_rules.local.yaml 2>/dev/null | head -1
timeout 60 falco -V /etc/falco/falco_rules.yaml -V /etc/falco/falco_rules.local.yaml >/tmp/ckx-val-v.out 2>&1; echo "RC=$?"
grep -iE 'error|invalid|undefined|unknown' /tmp/ckx-val-v.out | head -2
rm -f /tmp/ckx-val-v.out
EOF
)
echo "$R" | grep -qx 'devmem' || { echo "❌ /etc/falco/falco_rules.local.yaml of $NODE01 has no rule named devmem"; exit 1; }
echo "$R" | grep -q '^RC=0' || { echo "❌ The rules do not compile: $(echo "$R" | sed -n '/^RC=/,$p' | sed 1d | head -1 | cut -c1-200)"; exit 1; }

echo "✅ The local rules file is valid and defines the rule devmem"
exit 0
