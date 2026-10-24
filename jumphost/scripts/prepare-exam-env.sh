#!/bin/bash
exec >> /proc/1/fd/1 2>&1


# Log function with timestamp
log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# Set defaults
NUMBER_OF_NODES=${1:-1}
EXAM_ID=${2:-""}

echo "Exam ID: $EXAM_ID"
echo "Number of nodes: $NUMBER_OF_NODES"

#check docker is running
if ! docker info > /dev/null 2>&1; then
  log "Docker is not running"
  log "Attempting to start docker"
  dockerd &
  sleep 5
  #check docker is running 3 times with 5 second interval
  for i in {1..3}; do
    if docker info > /dev/null 2>&1; then
      log "Docker started successfully"
      break
    fi
    log "Docker failed to start, retrying..."
    sleep 5
  done
fi

log "Starting exam environment preparation with $NUMBER_OF_NODES node(s)"

# Validate input
if ! [[ "$NUMBER_OF_NODES" =~ ^[0-9]+$ ]]; then
  log "ERROR: Number of nodes must be a positive integer"
  exit 1
fi

# Setup cluster (skipped when an external kubeconfig was installed by the
# "external-cluster" compose profile)
if [ -f /home/candidate/.kube/.external-cluster ]; then
  log "External cluster mode: using the provided kubeconfig, skipping k3d creation"

  # Install the provided SSH config and keys so "ssh <node>" works as in the exam
  SSH_SRC=/home/candidate/.kube/.ssh-external
  if [ -d "$SSH_SRC" ]; then
    mkdir -p /home/candidate/.ssh
    cp -R "$SSH_SRC"/. /home/candidate/.ssh/
    chmod 700 /home/candidate/.ssh
    find /home/candidate/.ssh -type f -exec chmod 600 {} \;
    if [ -f /home/candidate/.ssh/config ]; then
      # keys live in ~/.ssh here, whatever path the original config used
      sed -i -E 's#^([[:space:]]*IdentityFile[[:space:]]+)(.*/)?([^/[:space:]]+)[[:space:]]*$#\1~/.ssh/\3#' /home/candidate/.ssh/config
      printf '\nHost *\n  StrictHostKeyChecking no\n  UserKnownHostsFile /dev/null\n  LogLevel ERROR\n' >> /home/candidate/.ssh/config
    fi
    log "SSH config installed in /home/candidate/.ssh"
  else
    log "No SSH directory provided: nodes will not be reachable over SSH"
  fi
else
  ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null candidate@k8s-api-server "env-setup $NUMBER_OF_NODES $CLUSTER_NAME"
fi

#Pull assets from URL
curl facilitator:3000/api/v1/exams/$EXAM_ID/assets -o assets.tar.gz

mkdir -p /tmp/exam-assets
#Unzip assets
tar -xzvf assets.tar.gz -C /tmp/exam-assets    

#Remove assets.tar.gz
rm assets.tar.gz

#make every file in /tmp/exam-assets executable
find /tmp/exam-assets -type f -exec chmod +x {} \;

echo "Exam assets downloaded and prepared successfully" 

# The exams do not know the names of the nodes: find out which nodes of this cluster are the control plane and
# the first and second worker (ckx-node-vars reads the ssh aliases and the cluster) and keep the result: the setups,
# the validators and the facilitator (it renders {{NODE01}} ... in the questions) read it
KUBECONFIG=/home/candidate/.kube/kubeconfig ckx-node-vars --write || log "WARNING: could not determine the node names, the defaults are used"

# Optional exam hook: runs before the cluster is used (e.g. restore nodes to a checkpoint)
if [ -x /tmp/exam-assets/scripts/pre-setup.sh ]; then
  log "Running exam pre-setup hook"
  /tmp/exam-assets/scripts/pre-setup.sh || { log "ERROR: pre-setup hook failed"; exit 1; }
fi

export KUBECONFIG=/home/candidate/.kube/kubeconfig

sleep 5

#wait till api-server is ready
while ! kubectl get nodes > /dev/null 2>&1; do
  log "API server is not ready, retrying..."
  sleep 5
done

echo "API server is ready"

#Run setup scripts
for script in /tmp/exam-assets/scripts/setup/q*_setup.sh; do $script; done

log "Exam environment preparation completed successfully"
exit 0 