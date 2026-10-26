#!/bin/bash
# Source this file (question 1, Falco). run_candidate_falco runs the candidate's rule file on node01
# for ~25 s with a standalone Falco (never the system service, no output file), while the host itself
# reads the sensitive file, and sets FALCO_JSON to the JSON events and FALCO_ERR to the first error.
# The result is cached for 2 minutes per rule file content: the validators of the question run
# one after the other and must not repeat a 35 s run each.
#   - the rule file is /tmp/exam/mhagou-008-q1/catch-rogue.yaml on the jumphost, or on node01
#   - a rule file that needs the default macros (container, open_read ...) is tried again with the
#     default rules loaded first
# Returns 1 and prints the reason when there is nothing to judge.

source "$(dirname "${BASH_SOURCE[0]}")/nodes.sh"
Q1_DIR="${Q1_DIR:-/tmp/exam/mhagou-008-q1}"
Q1_NODE="${NODE01}"
FALCO_JSON=""; FALCO_ERR=""; FALCO_LOADED=0; RULE_NAMES="[]"

q1_rule_content() {
  if [ -s "$Q1_DIR/catch-rogue.yaml" ]; then
    cat "$Q1_DIR/catch-rogue.yaml"
  else
    ssh -o StrictHostKeyChecking=no "$Q1_NODE" "cat '$Q1_DIR/catch-rogue.yaml'" 2>/dev/null
  fi
}

q1_falco_once() { # extra -r arguments (the default rules) as $1
  ssh -o StrictHostKeyChecking=no "$Q1_NODE" "EXTRA='$1' DATA='$Q1_DIR/data/secret.txt' bash -s" <<'REMOTE'
timeout 80 falco $EXTRA -r /tmp/ckx-val-q1.yaml -M 25 -o json_output=true -o stdout_output.enabled=true \
  -o file_output.enabled=false -o syslog_output.enabled=false -o program_output.enabled=false \
  -o http_output.enabled=false -o webserver.enabled=false >/tmp/ckx-val-q1.out 2>/tmp/ckx-val-q1.err &
FP=$!
for i in 1 2 3 4 5 6 7 8 9 10; do sleep 2; cat "$DATA" >/dev/null 2>&1; done
wait $FP; echo "#RC=$?"
cat /tmp/ckx-val-q1.out
echo "#ERR"
grep -iE 'error|invalid|cannot|undefined|unknown' /tmp/ckx-val-q1.err | head -2
rm -f /tmp/ckx-val-q1.out /tmp/ckx-val-q1.err
REMOTE
}

run_candidate_falco() {
  local content key cache RAW2
  content=$(q1_rule_content)
  if [ -z "$content" ]; then
    echo "❌ The rule file $Q1_DIR/catch-rogue.yaml does not exist (neither on the jumphost nor on $Q1_NODE) or is empty"
    return 1
  fi
  key=$(printf '%s' "$content" | md5sum | cut -c1-12)
  cache="/tmp/ckx-falco-q1.$key"
  if [ -f "$cache" ] && [ $(( $(date +%s) - $(stat -c %Y "$cache") )) -lt 120 ]; then
    RAW=$(cat "$cache")
  else
    printf '%s\n' "$content" | ssh -o StrictHostKeyChecking=no "$Q1_NODE" "cat > /tmp/ckx-val-q1.yaml"
    RAW=$(q1_falco_once "")
    if ! echo "$RAW" | grep -q '^#RC=0'; then
      # maybe the rules use the macros of the default rules: load those first
      RAW2=$(q1_falco_once "-r /etc/falco/falco_rules.yaml")
      if echo "$RAW2" | grep -q '^#RC=0'; then RAW="$RAW2"; fi
    fi
    ssh -o StrictHostKeyChecking=no "$Q1_NODE" "rm -f /tmp/ckx-val-q1.yaml" 2>/dev/null
    printf '%s\n' "$RAW" > "$cache"
  fi
  if ! echo "$RAW" | grep -q '^#RC=0'; then
    FALCO_ERR=$(echo "$RAW" | sed -n '/^#ERR/,$p' | sed 1d | head -1 | cut -c1-200)
    echo "❌ Falco does not run with your rule file: ${FALCO_ERR:-unknown error}"
    return 1
  fi
  FALCO_LOADED=1
  RULE_NAMES=$(q1_rule_names "$content")
  FALCO_JSON=$(echo "$RAW" | sed '/^#ERR/,$d' | jq -cR 'fromjson? | select(type == "object")' 2>/dev/null)
}

# prefix (12 characters) of the container id of the demonstration Pod
q1_container_id() {
  kubectl get pod rogue-pod -n forensics-lab -o jsonpath='{.status.containerStatuses[0].containerID}' 2>/dev/null | sed 's#.*://##' | cut -c1-12
}

# names of the rules defined in the candidate's file (the default rules, loaded as a fallback, are not judged)
q1_rule_names() {
  printf '%s\n' "$1" | sed -nE 's/^[[:space:]-]*rule:[[:space:]]*//p' | sed -E "s/[[:space:]]+\$//; s/^[\"']//; s/[\"']\$//" | jq -R . | jq -sc .
}

# alerts of the candidate's rules about the sensitive file: the text or the fields mention the file name
# or its directory (/data). The output format is judged by its own item, not here.
q1_file_events() {
  echo "$FALCO_JSON" | jq -c --argjson rules "$RULE_NAMES" 'select(.rule as $r | $rules | index($r) != null)
    | select((.output + ((.output_fields // {}) | tostring)) | test("secret\\.txt|/data"))' 2>/dev/null
}

# those alerts that point at the rogue container: its id or its name in the text or in the fields
q1_container_events() {
  local cid; cid=$(q1_container_id)
  q1_file_events | jq -c --arg cid "${cid:-none}" 'select((.output + ((.output_fields // {}) | tostring)) | (contains($cid) or contains("snooper-container")))' 2>/dev/null
}

# the other alerts: raised for a process that is not in the rogue container (the host reads of the validator)
q1_host_events() {
  local cid; cid=$(q1_container_id)
  q1_file_events | jq -c --arg cid "${cid:-none}" 'select((.output + ((.output_fields // {}) | tostring)) | (contains($cid) or contains("snooper-container")) | not)' 2>/dev/null
}
