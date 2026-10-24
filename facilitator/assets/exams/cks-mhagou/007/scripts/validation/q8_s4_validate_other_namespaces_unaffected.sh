#!/bin/bash
# Item: namespaces whose name does not start with lab- are not affected (credited once the policy rejects namespaces without the label)

source "$(dirname "$0")/../lib/nspolicy.sh"
ns_denied_probe || { echo "❌ The policy does not reject namespaces without the label yet, nothing to credit"; exit 1; }

OUT=$(ns_create_probe "ckx-other$RANDOM$RANDOM")
echo "$OUT" | ns_rejected && { echo "❌ A namespace that does not start with lab- is rejected: the policy must be limited to the namespaces named lab-*"; exit 1; }

echo "✅ Namespaces that do not start with lab- are not affected"
exit 0
