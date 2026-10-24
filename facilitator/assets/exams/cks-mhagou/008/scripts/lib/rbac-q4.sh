#!/bin/bash
# Source this file (question 4). Helpers to judge ci-bot as the API server does.

Q4_NS="ci-cd"
BOT=(--as=system:serviceaccount:ci-cd:ci-bot --as-group=system:serviceaccounts --as-group=system:serviceaccounts:ci-cd --as-group=system:authenticated)

# can_i VERB RESOURCE [-n NS]  -> "yes" / "no"
can_i() { kubectl "${BOT[@]}" auth can-i "$@" 2>/dev/null; }

# bind_forbidden KIND ROLE: the server (dry-run) refuses ci-bot a binding to the role KIND/ROLE
# (RoleBinding in ci-cd or ClusterRoleBinding). Returns 0 when forbidden, 1 when allowed, 2 on any other error.
bind_forbidden() {
  local kind="$1" role="$2" ref out
  if [ "$kind" = "cluster" ]; then
    out=$(kubectl "${BOT[@]}" create clusterrolebinding "ckx-probe-$RANDOM" --clusterrole="$role" --serviceaccount="$Q4_NS:ci-bot" --dry-run=server -o name 2>&1)
  else
    out=$(kubectl "${BOT[@]}" create rolebinding "ckx-probe-$RANDOM" --clusterrole="$role" --serviceaccount="$Q4_NS:ci-bot" -n "$Q4_NS" --dry-run=server -o name 2>&1)
  fi
  [ $? -eq 0 ] && return 1
  echo "$out" | grep -qi 'forbidden' && return 0
  echo "$out" | head -1 >&2
  return 2
}

# "the escalation is closed": ci-bot cannot bind itself to cluster-admin nor to admin in any scope
escalation_closed() {
  local k r
  for k in cluster namespace; do
    for r in cluster-admin admin; do
      bind_forbidden "$k" "$r" || return 1
    done
  done
  return 0
}
