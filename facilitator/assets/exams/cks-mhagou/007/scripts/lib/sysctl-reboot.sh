#!/bin/bash
# Source this file. sysctl_after_reboot_emulation emulates what the next boot does to the two kernel
# parameters of question 7 on node02: the live values are set to the kernel default (1), all the sysctl
# files are applied (sysctl --system) and the result is read; then the live values are put back.
# Sets REBOOT_ACCEPT and REBOOT_SEND. No cache: the state of the files may change between two runs.

REBOOT_ACCEPT=""; REBOOT_SEND=""

sysctl_after_reboot_emulation() {
  local R
  R=$(ssh -o StrictHostKeyChecking=no node02 'bash -s' <<'EOF'
A=$(sysctl -n net.ipv4.conf.default.accept_redirects); S=$(sysctl -n net.ipv4.conf.default.send_redirects)
sysctl -q -w net.ipv4.conf.default.accept_redirects=1 net.ipv4.conf.default.send_redirects=1
sysctl --system >/dev/null 2>&1
echo "$(sysctl -n net.ipv4.conf.default.accept_redirects) $(sysctl -n net.ipv4.conf.default.send_redirects)"
sysctl -q -w net.ipv4.conf.default.accept_redirects=$A net.ipv4.conf.default.send_redirects=$S
EOF
)
  set -- $R
  [ -n "$1" ] && [ -n "$2" ] || return 1
  REBOOT_ACCEPT="$1"; REBOOT_SEND="$2"
}
