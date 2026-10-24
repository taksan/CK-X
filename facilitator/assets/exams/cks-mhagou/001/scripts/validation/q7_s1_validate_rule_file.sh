#!/bin/bash
# Item: /etc/falco/falco_rules.local.yaml on node01 holds a rule with priority WARNING for /etc/shadow whose
# output starts with "SHADOW READ", and Falco accepts the file
source "$(dirname "$0")/../lib/nodes.sh"

FILE=/etc/falco/falco_rules.local.yaml
J=$(ssh -o StrictHostKeyChecking=no node01 "yq -o=json '.' $FILE" 2>/dev/null)
[ -n "$J" ] && [ "$J" != "null" ] || { echo "❌ $FILE does not exist on $NODE01, is empty or is not valid YAML"; exit 1; }

if ! echo "$J" | jq -e 'type == "array" and any(.[]; (.rule != null) and ((.priority // "" | ascii_downcase) == "warning") and ((.condition // "") | contains("shadow")) and ((.output // "") | startswith("SHADOW READ")))' >/dev/null 2>&1; then
  echo "❌ $FILE has no rule with priority WARNING, a condition on /etc/shadow and an output starting with 'SHADOW READ'"
  exit 1
fi

# the macros of the default rules (open_read, ...) must be loaded before the custom file, as the service does
if ! ssh -o StrictHostKeyChecking=no node01 "falco -V /etc/falco/falco_rules.yaml -V $FILE >/dev/null 2>&1"; then
  echo "❌ Falco rejects $FILE (falco -V /etc/falco/falco_rules.yaml -V $FILE shows the error; an output with a colon needs quotes)"
  exit 1
fi

echo "✅ $FILE has the WARNING rule for /etc/shadow and Falco accepts it"
exit 0
