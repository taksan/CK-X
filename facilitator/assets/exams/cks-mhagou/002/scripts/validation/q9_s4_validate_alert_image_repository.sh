#!/bin/bash
# The fourth field of the alert is the repository of the container image (docker.io/library/busybox)

source "$(dirname "$0")/../lib/falco-shell.sh"
falco_shell_alert || exit 1

REPO_FIELD=$(echo "$ALERT_OUTPUT" | awk -F, '{print $4}' | awk '{print $1}')
case "$REPO_FIELD" in
  docker.io/library/busybox|busybox|index.docker.io/library/busybox) ;;
  *) echo "❌ The fourth field of the alert is '${REPO_FIELD:0:60}', expected the image repository (busybox) (alert: ${ALERT_OUTPUT:0:100})"; exit 1 ;;
esac
echo "✅ The fourth field of the alert is the image repository ($REPO_FIELD)"
exit 0
