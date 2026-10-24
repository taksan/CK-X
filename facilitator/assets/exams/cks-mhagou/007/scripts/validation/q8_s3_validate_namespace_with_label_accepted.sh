#!/bin/bash
# Item: a namespace lab-... with the label env (any value, also an empty one) is accepted
# (credited once the policy rejects namespaces without the label)

source "$(dirname "$0")/../lib/nspolicy.sh"
ns_denied_probe || { echo "❌ The policy does not reject namespaces without the label yet, nothing to credit"; exit 1; }

OUT=$(ns_create_probe "lab-ckx$RANDOM$RANDOM" '    env: prod')
echo "$OUT" | ns_rejected && { echo "❌ A namespace lab-... with the label env=prod is rejected: $(echo "$OUT" | head -1 | cut -c1-150)"; exit 1; }
OUT=$(ns_create_probe "lab-ckx$RANDOM$RANDOM" '    env: ""')
echo "$OUT" | ns_rejected && { echo "❌ A namespace lab-... with the label env set to an empty value is rejected (only the key matters)"; exit 1; }

echo "✅ Namespaces lab-... with the label env are accepted (any value)"
exit 0
