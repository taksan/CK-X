#!/bin/bash
# Item: send_redirects = 0 is persistent (value obtained when all sysctl files are applied again, as at boot)

source "$(dirname "$0")/../lib/sysctl-reboot.sh"
source "$(dirname "$0")/../lib/nodes.sh"
sysctl_after_reboot_emulation || { echo "❌ Unable to emulate the reapplication of the sysctl files on $NODE02"; exit 1; }
[ "$REBOOT_SEND" = "0" ] || { echo "❌ After the sysctl files are applied again net.ipv4.conf.default.send_redirects is '$REBOOT_SEND': the setting is not persistent"; exit 1; }

echo "✅ net.ipv4.conf.default.send_redirects = 0 after a reboot (persistent)"
exit 0
