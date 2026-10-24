#!/bin/bash
# Source this file (question 6). dockerd_lab_state reads the state of dockerd-lab on node01 once it is stable
# (a daemon that refuses its configuration exits right after it started and systemd restarts it every 2 s:
# the service must be active with the same main process during 2 seconds). It sets
#   DL_RUN   yes|no     the service runs stably
#   DL_GROUP            group of /run/dockerd-lab.sock (none when absent)
#   DL_TCP              number of listeners on TCP 2375
#   DL_SOCK  sock|nosock
# With an argument "restart" the service is reloaded and restarted first.

DL_RUN=""; DL_GROUP=""; DL_TCP=""; DL_SOCK=""

dockerd_lab_state() {
  local R
  R=$(ssh -o StrictHostKeyChecking=no node01 "MODE=$1 bash -s" <<'EOF'
if [ "$MODE" = "restart" ]; then
  systemctl daemon-reload
  systemctl restart dockerd-lab.service >/dev/null 2>&1
fi
sleep 3
A1=$(systemctl is-active dockerd-lab.service); P1=$(systemctl show -p MainPID --value dockerd-lab.service)
sleep 2
A2=$(systemctl is-active dockerd-lab.service); P2=$(systemctl show -p MainPID --value dockerd-lab.service)
RUN=no
[ "$A1" = active ] && [ "$A2" = active ] && [ "$P1" = "$P2" ] && [ "$P1" != 0 ] && RUN=yes
echo "$RUN $(stat -c %G /run/dockerd-lab.sock 2>/dev/null || echo none) $(ss -ltnH | awk '{print $4}' | grep -c ':2375$') $([ -S /run/dockerd-lab.sock ] && echo sock || echo nosock)"
EOF
)
  set -- $R
  [ -n "$4" ] || return 1
  DL_RUN="$1"; DL_GROUP="$2"; DL_TCP="$3"; DL_SOCK="$4"
}
