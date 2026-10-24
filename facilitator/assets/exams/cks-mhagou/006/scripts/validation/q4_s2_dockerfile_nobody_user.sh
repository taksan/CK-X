#!/bin/bash
# The final stage runs as nobody: its last USER instruction is nobody. A USER root earlier in a stage is fine
# (installing packages needs root), but a package installation must not run as nobody: the build would break
F="${Q4_DOCKERFILE:-/tmp/exam/mhagou-006-q4/Dockerfile}"
[ -f "$F" ] || { echo "❌ $F does not exist"; exit 1; }
P=$(python3 "$(dirname "$0")/../lib/dockerfile_q4.py" "$F" 2>/dev/null)
[ -n "$P" ] || { echo "❌ $F cannot be parsed as a Dockerfile"; exit 1; }

LAST=$(echo "$P" | jq -r '.stages | last | .users | last // empty')
case "$LAST" in
  nobody|65534|65535) ;;
  "") echo "❌ The final stage does not select a runtime user (add USER nobody)"; exit 1 ;;
  *) echo "❌ The final stage ends with USER '$LAST', expected nobody"; exit 1 ;;
esac

# the user in force at every package installation (it starts as root in every stage)
BROKEN=$(echo "$P" | jq -r '[.instructions | reduce .[] as $i ({user: "root", bad: []};
    if $i[0] == "FROM" then .user = "root"
    elif $i[0] == "USER" then .user = ($i[1] | split(" ")[0] | split(":")[0])
    elif $i[0] == "RUN" and ($i[1] | test("(apt|apt-get|apk|yum|dnf)[[:space:]]+(install|add|update|upgrade)")) and (.user | IN("nobody", "65534", "65535")) then .bad += [$i[1]]
    else . end) | .bad[]] | length')
[ "$BROKEN" = "0" ] || { echo "❌ A package installation runs as nobody, which cannot work: install as root and switch to nobody afterwards"; exit 1; }

echo "✅ The final stage runs as nobody and the installation steps still run as root"
exit 0
