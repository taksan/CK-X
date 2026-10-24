#!/bin/bash
exec >> /proc/1/fd/1 2>&1

# cleanup-exam-env.sh
# 
# This script cleans up the exam environment on the jumphost.
# It removes all resources created during the exam to prepare for a new exam.
#
# Usage: cleanup-exam-env.sh
#
# Example: cleanup-exam-env.sh

# Log function with timestamp
log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

log "Starting exam environment cleanup"
if [ -f /home/candidate/.kube/.external-cluster ]; then
  # Never delete a user-provided cluster
  log "External cluster mode: leaving the cluster untouched"
else
  log "Cleaning up cluster $CLUSTER_NAME"
  ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null candidate@k8s-api-server "env-cleanup $CLUSTER_NAME"
fi

# Optional exam hook: removes what the exam created on a persistent cluster
if [ -x /tmp/exam-assets/scripts/session-cleanup.sh ]; then
  log "Running exam session-cleanup hook"
  /tmp/exam-assets/scripts/session-cleanup.sh || log "WARNING: session-cleanup hook reported errors"
fi

#cleanup docker env
log "Cleaning up docker environment"
docker system prune -a --volumes -fa
docker network prune -fa
docker image prune -fa

# Remove the exam environment directory
log "Removing exam environment directory"
rm -rf /tmp/exam-env
rm -rf /tmp/exam

# Remove the exam assets directory
log "Removing exam assets directory"
rm -rf /tmp/exam-assets

log "Exam environment cleanup completed successfully"
exit 0 