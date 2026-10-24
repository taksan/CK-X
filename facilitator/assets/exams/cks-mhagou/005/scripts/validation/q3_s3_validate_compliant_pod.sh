#!/bin/bash
# A Pod of api-security is Running and Ready and every container (init and ephemeral included)
# runs as non-root with allowPrivilegeEscalation false, not privileged and without SYS_ADMIN

NS="api-security"
J=$(kubectl get pods -n "$NS" -o json 2>/dev/null)
[ "$(echo "$J" | jq '[.items[] | select(.metadata.deletionTimestamp == null)] | length')" != "0" ] || { echo "❌ There is no Pod in the namespace $NS"; exit 1; }

READY=$(echo "$J" | jq -r '.items[] | select(.metadata.deletionTimestamp == null and .status.phase == "Running" and ([.status.conditions[]? | select(.type == "Ready" and .status == "True")] | length == 1)) | .metadata.name')
[ -n "$READY" ] || { echo "❌ No Pod of $NS is Running and Ready"; exit 1; }

PROBLEM=""
for pod in $READY; do
  P=$(echo "$J" | jq -c --arg n "$pod" '.items[] | select(.metadata.name == $n)')
  BAD=$(echo "$P" | jq -r '
    (.spec.securityContext.runAsNonRoot // false) as $podnr
    | (.spec.securityContext.runAsUser) as $podu
    | [(.spec.initContainers // []), .spec.containers, (.spec.ephemeralContainers // [])] | add | .[]
    | . as $c
    | ($c.securityContext // {}) as $sc
    | [ (if (($sc.runAsNonRoot // $podnr) == true or (($sc.runAsUser // $podu // 0) != 0)) then empty else "runs as root" end),
        (if $sc.allowPrivilegeEscalation == false then empty else "allowPrivilegeEscalation is not false" end),
        (if $sc.privileged == true then "is privileged" else empty end),
        (if (($sc.capabilities.add // []) | index("SYS_ADMIN")) != null then "adds SYS_ADMIN" else empty end) ]
    | select(length > 0) | "container \($c.name): " + join(", ")')
  if [ -z "$BAD" ]; then
    UIDV=$(kubectl exec -n "$NS" "$pod" -- id -u 2>/dev/null)
    if [ -n "$UIDV" ] && [ "$UIDV" != "0" ]; then
      echo "✅ Pod $pod is Running and Ready and compliant (non-root uid $UIDV, no privilege escalation, not privileged)"
      exit 0
    fi
    PROBLEM="${PROBLEM:-Pod $pod: its process runs as uid ${UIDV:-unknown} (non-root required)}"
  else
    PROBLEM="${PROBLEM:-Pod $pod: $(echo "$BAD" | head -1)}"
  fi
done
echo "❌ No Running and Ready Pod is compliant. $PROBLEM"
exit 1
