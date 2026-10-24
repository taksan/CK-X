#!/bin/bash
# Item 5: the stage RequestReceived is omitted (for the whole policy, or in every rule)

source "$(dirname "$0")/../lib/audit-policy.sh"
load_audit_policy || exit 1

if echo "$AUDIT_POLICY_JSON" | jq -e '(.omitStages // []) | index("RequestReceived") != null' >/dev/null; then
  echo "✅ RequestReceived is omitted in the whole policy"
  exit 0
fi

if echo "$AUDIT_POLICY_JSON" | jq -e '(.rules | length > 0) and all(.rules[]; (.level == "None") or ((.omitStages // []) | index("RequestReceived") != null))' >/dev/null; then
  echo "✅ RequestReceived is omitted in every rule"
  exit 0
fi

MISSING=$(echo "$AUDIT_POLICY_JSON" | jq -r '[.rules | to_entries[] | select(.value.level != "None" and ((.value.omitStages // []) | index("RequestReceived") == null)) | .key + 1] | map(tostring) | join(", ")')
echo "❌ The stage RequestReceived is not omitted: set omitStages at the top of the policy (rules without it: $MISSING)"
exit 1
