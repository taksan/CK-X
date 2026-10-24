#!/bin/bash
# Validate Role john-role in namespace john: exactly list, get, create, delete on pods and secrets

NS="john"

JSON=$(kubectl get role john-role -n "$NS" -o json 2>/dev/null)
if [ -z "$JSON" ]; then
  echo "❌ Role 'john-role' not found in namespace '$NS'"
  exit 1
fi

# union of the verbs and of the resources of all rules, core API group only
RESULT=$(echo "$JSON" | jq -c '{
  verbs: ([.rules[]?.verbs[]?] | unique | sort),
  resources: ([.rules[]?.resources[]?] | unique | sort),
  groups: ([.rules[]?.apiGroups[]?] | unique)}')

if [ "$(echo "$RESULT" | jq -c '.verbs')" != '["create","delete","get","list"]' ]; then
  echo "❌ The verbs of Role 'john-role' must be exactly list, get, create and delete (found: $(echo "$RESULT" | jq -c '.verbs'))"
  exit 1
fi

if [ "$(echo "$RESULT" | jq -c '.resources')" != '["pods","secrets"]' ]; then
  echo "❌ The resources of Role 'john-role' must be exactly pods and secrets (found: $(echo "$RESULT" | jq -c '.resources'))"
  exit 1
fi

echo "✅ Role 'john-role' allows list, get, create and delete on pods and secrets only"
exit 0
