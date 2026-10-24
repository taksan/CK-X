#!/bin/bash
# Source this file to evaluate the audit policy that the API server uses, the way the API server
# does: for a request the FIRST rule that matches decides the level (no rule: None).
#
#   load_audit_policy          reads --audit-policy-file from the kube-apiserver manifest on the control
#                              plane (override: AUDIT_POLICY_FILE) and sets AUDIT_POLICY_JSON; on failure
#                              it prints the reason and returns 1
#   audit_level G R S NS VERB  level of a request: group, resource, subresource ("" for none), namespace
#                              ("" for cluster scoped) and verb, made by a regular user (kubernetes-admin)
#   audit_rule_index ...       index of the first matching rule ("none" if no rule matches)

source "$(dirname "${BASH_SOURCE[0]}")/nodes.sh"

AUDIT_NODE="${AUDIT_NODE:-$CONTROL_PLANE}"
AUDIT_POLICY_JSON=""

load_audit_policy() {
  local file="${AUDIT_POLICY_FILE:-}"
  if [ -z "$file" ]; then
    file=$(ssh -o StrictHostKeyChecking=no "$AUDIT_NODE" "yq -o=json '.spec.containers[0].command' /etc/kubernetes/manifests/kube-apiserver.yaml" 2>/dev/null \
      | jq -r '.[] | select(startswith("--audit-policy-file="))' 2>/dev/null | head -1 | cut -d= -f2-)
  fi
  if [ -z "$file" ]; then
    echo "❌ kube-apiserver has no --audit-policy-file"
    return 1
  fi
  AUDIT_POLICY_JSON=$(ssh -o StrictHostKeyChecking=no "$AUDIT_NODE" "yq -o=json '.' '$file'" 2>/dev/null)
  if [ -z "$AUDIT_POLICY_JSON" ] || ! echo "$AUDIT_POLICY_JSON" | jq -e '.kind == "Policy" and (.rules | type == "array")' >/dev/null 2>&1; then
    echo "❌ $file is missing or is not a valid audit Policy (kind: Policy with a list of rules)"
    return 1
  fi
}

# jq program: first matching rule for the request ($g, $r, $s, $ns, $verb)
_AUDIT_JQ='
def res_match($g; $r; $s):
  (.group // "") == $g and
  ((.resources // []) | length == 0 or any(.[]; . as $x |
      $x == "*" or
      ($s == "" and $x == $r) or
      ($s != "" and ($x == ($r + "/" + $s) or $x == ($r + "/*") or $x == ("*/" + $s) or $x == "*/*"))));
def rule_match($g; $r; $s; $ns; $verb):
  ((.nonResourceURLs // []) | length == 0) and
  ((.verbs // []) | length == 0 or index($verb) != null) and
  ((.users // []) | length == 0 or index("kubernetes-admin") != null) and
  ((.userGroups // []) | length == 0 or any(.[]; . == "system:masters" or . == "system:authenticated")) and
  ((.namespaces // []) | length == 0 or index($ns) != null) and
  ((.resources // []) as $rs | ($rs | length) == 0 or any($rs[]; res_match($g; $r; $s)));
[ .rules | to_entries[] | select(.value | rule_match($g; $r; $s; $ns; $verb)) ] | first // null
'

_audit_first_rule() {
  echo "$AUDIT_POLICY_JSON" | jq -c --arg g "$1" --arg r "$2" --arg s "$3" --arg ns "$4" --arg verb "$5" "$_AUDIT_JQ"
}

audit_level() {
  local m; m=$(_audit_first_rule "$@")
  if [ "$m" = "null" ] || [ -z "$m" ]; then echo "None"; else echo "$m" | jq -r '.value.level // "None"'; fi
}

audit_rule_index() {
  local m; m=$(_audit_first_rule "$@")
  if [ "$m" = "null" ] || [ -z "$m" ]; then echo "none"; else echo "$m" | jq -r '.key + 1'; fi
}

# check_audit_level DESCRIPTION EXPECTED G R S NS VERB: prints a diagnosis and returns 1 on mismatch
check_audit_level() {
  local desc="$1" expected="$2"; shift 2
  local got; got=$(audit_level "$@")
  if [ "$got" != "$expected" ]; then
    local idx; idx=$(audit_rule_index "$@")
    local what="$2${3:+/$3}"; [ -n "$1" ] && what="$what (group $1)"
    echo "❌ $desc: $5 $what${4:+ in namespace $4} is logged at level $got (rule #$idx of the policy), expected $expected"
    return 1
  fi
  return 0
}
