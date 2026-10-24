#!/bin/bash
# Validate the rule definition in /etc/falco/falco_rules.local.yaml of node01: name, priority,
# output and a condition about /dev/mem

source "$(dirname "$0")/../lib/nodes.sh"
RULES=$(ssh -o StrictHostKeyChecking=no node01 "yq -o=json '.' /etc/falco/falco_rules.local.yaml" 2>/dev/null)
[ -n "$RULES" ] || { echo "❌ /etc/falco/falco_rules.local.yaml of ${NODE01} is missing, empty or not valid YAML"; exit 1; }

R=$(echo "$RULES" | jq -c '[.[]? | select(.rule == "Detect dev mem access")][0] // empty' 2>/dev/null)
[ -n "$R" ] || { echo "❌ No rule named 'Detect dev mem access' in /etc/falco/falco_rules.local.yaml of ${NODE01}"; exit 1; }

[ "$(echo "$R" | jq -r '.priority // ""' | tr 'a-z' 'A-Z')" = "WARNING" ] || { echo "❌ The priority of the rule is '$(echo "$R" | jq -r '.priority // "(none)"')', expected WARNING"; exit 1; }
[ "$(echo "$R" | jq -r '.output // ""')" = "Sensitive file opened (user=%user.name command=%proc.cmdline file=%fd.name)" ] \
  || { echo "❌ The output of the rule is '$(echo "$R" | jq -r '.output // "(none)"')', expected: Sensitive file opened (user=%user.name command=%proc.cmdline file=%fd.name)"; exit 1; }
echo "$R" | jq -e '(.condition // "") | (contains("fd.name") and contains("/dev/mem"))' >/dev/null \
  || { echo "❌ The condition of the rule does not test fd.name against /dev/mem"; exit 1; }

echo "✅ The rule 'Detect dev mem access' has the requested priority, output and a condition on /dev/mem"
exit 0
