#!/bin/bash
# Validate on the second worker node: the message "CRITICAL: SHELL OPENED" is configured in the Falco files and Falco
# runs stably (not crash-looping) with a process that was started after the file was written, so the
# running service has loaded it

source "$(dirname "$0")/../lib/nodes.sh"

NODE="$NODE02"

R=$(ssh -o StrictHostKeyChecking=no "$NODE" 'bash -s' <<'EOF'
FILES=$(grep -rIl 'SHELL OPENED' /etc/falco 2>/dev/null | head -5)
[ -n "$FILES" ] || { echo "NOFILE"; exit 0; }
UNIT=""; PID=""
# a restart takes several seconds: accept a service that has been running for at least 10 seconds
for i in $(seq 1 30); do
  UNIT=$(systemctl list-units 'falco-*' --state=active --no-legend 2>/dev/null | grep -v falcoctl | awk '{print $1}' | head -1)
  if [ -n "$UNIT" ]; then
    PID=$(systemctl show -p MainPID --value "$UNIT")
    AGE=$(ps -o etimes= -p "$PID" 2>/dev/null | tr -d ' ')
    [ -n "$AGE" ] && [ "$AGE" -ge 10 ] && break
  fi
  UNIT=""; sleep 2
done
[ -n "$UNIT" ] || { echo "NOSERVICE"; exit 0; }
START=$(date -d "$(ps -o lstart= -p "$PID" 2>/dev/null)" +%s 2>/dev/null)
NEWEST=0
for f in $FILES; do m=$(stat -c %Y "$f"); [ "$m" -gt "$NEWEST" ] && NEWEST=$m; done
if [ -n "$START" ] && [ "$START" -ge "$NEWEST" ]; then echo "OK $UNIT"; else echo "NOTRESTARTED $UNIT"; fi
EOF
)

case "$R" in
  NOFILE) echo "❌ The text 'SHELL OPENED' is not configured anywhere under /etc/falco on $NODE"; exit 1 ;;
  NOSERVICE) echo "❌ Falco is not running stably on $NODE (stopped, or restarting in a loop): run 'falco -o engine.kind=modern_ebpf' on the node to see the rule error (for example a YAML value that contains ': ' must be quoted)"; exit 1 ;;
  NOTRESTARTED*) echo "❌ Falco on $NODE was not restarted after the rule was written: the running service has not loaded it (systemctl restart ${R#NOTRESTARTED })"; exit 1 ;;
  OK*) echo "✅ The message is configured and the Falco service (${R#OK }) was restarted afterwards"; exit 0 ;;
  *) echo "❌ Unable to inspect Falco on $NODE"; exit 1 ;;
esac
