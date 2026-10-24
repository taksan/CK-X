#!/bin/bash
# fd 3 is the channel of the caller (the facilitator reads it over SSH): the progress lines go there, everything else
# goes to the log of the container
exec 3>&1
exec >> /proc/1/fd/1 2>&1


# Log function with timestamp
log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# Report progress to the facilitator (shown on the exam setup screen)
#   progress <percent> <run|ok> <step id> <message>
PERCENT=0
progress() {
  PERCENT=$1
  printf 'CKX-PROGRESS\t%s\t%s\t%s\t%s\n' "$1" "$2" "$3" "$4" >&3 2>/dev/null
  log "[$2] $4"
}

# Report a failed step with the end of its output (a file), then stop
#   fail <step id> <message> [output file]
fail() {
  printf 'CKX-PROGRESS\t%s\tfail\t%s\t%s\n' "$PERCENT" "$1" "$2" >&3 2>/dev/null
  log "ERROR: $2"
  if [ -n "$3" ] && [ -s "$3" ]; then
    tail -n 15 "$3" | tr -d '\r' | while IFS= read -r line; do printf 'CKX-OUTPUT\t%s\n' "$line" >&3 2>/dev/null; done
  fi
  exit 1
}

# Run a command keeping its output: shown in the log, and available to report a failure
#   run_logged <output file> <command...>
run_logged() {
  local out=$1
  shift
  "$@" > "$out" 2>&1
  local rc=$?
  cat "$out"
  return $rc
}

# Set defaults
NUMBER_OF_NODES=${1:-1}
EXAM_ID=${2:-""}

echo "Exam ID: $EXAM_ID"
echo "Number of nodes: $NUMBER_OF_NODES"

progress 3 run docker "Checking Docker"
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
  docker info > /dev/null 2>&1 || fail docker "Docker is not running on the jumphost and could not be started"
fi
progress 5 ok docker "Docker is running"

log "Starting exam environment preparation with $NUMBER_OF_NODES node(s)"

# Validate input
if ! [[ "$NUMBER_OF_NODES" =~ ^[0-9]+$ ]]; then
  fail input "Number of nodes must be a positive integer (got '$NUMBER_OF_NODES')"
fi

LOG_FILE=$(mktemp)
# Setup cluster (skipped when an external kubeconfig was installed by the
# "external-cluster" compose profile)
if [ -f /home/candidate/.kube/.external-cluster ]; then
  progress 8 run cluster "Using the provided external cluster"
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
  progress 45 ok cluster "External cluster ready"
else
  progress 8 run cluster "Creating the Kubernetes cluster ($NUMBER_OF_NODES node(s)), this is the longest step"
  run_logged "$LOG_FILE" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null candidate@k8s-api-server "env-setup $NUMBER_OF_NODES $CLUSTER_NAME" \
    || fail cluster "Creating the Kubernetes cluster failed" "$LOG_FILE"
  progress 45 ok cluster "Kubernetes cluster created"
fi

#Pull assets from URL
progress 47 run assets "Downloading the exam files"
run_logged "$LOG_FILE" curl -fsS facilitator:3000/api/v1/exams/$EXAM_ID/assets -o assets.tar.gz \
  || fail assets "Downloading the exam files failed" "$LOG_FILE"

mkdir -p /tmp/exam-assets
#Unzip assets
run_logged "$LOG_FILE" tar -xzvf assets.tar.gz -C /tmp/exam-assets \
  || fail assets "Unpacking the exam files failed" "$LOG_FILE"

#Remove assets.tar.gz
rm assets.tar.gz

#make every file in /tmp/exam-assets executable
find /tmp/exam-assets -type f -exec chmod +x {} \;

echo "Exam assets downloaded and prepared successfully" 
progress 50 ok assets "Exam files ready"

# The exams do not know the names of the nodes: find out which nodes of this cluster are the control plane and
# the first and second worker (ckx-node-vars reads the ssh aliases and the cluster) and keep the result: the setups,
# the validators and the facilitator (it renders {{NODE01}} ... in the questions) read it
KUBECONFIG=/home/candidate/.kube/kubeconfig ckx-node-vars --write || log "WARNING: could not determine the node names, the defaults are used"

# Optional exam hook: runs before the cluster is used (e.g. restore nodes to a checkpoint)
if [ -x /tmp/exam-assets/scripts/pre-setup.sh ]; then
  log "Running exam pre-setup hook"
  run_logged "$LOG_FILE" /tmp/exam-assets/scripts/pre-setup.sh || fail pre-setup "The exam pre-setup hook failed" "$LOG_FILE"
fi

export KUBECONFIG=/home/candidate/.kube/kubeconfig

sleep 5

#wait till api-server is ready
progress 52 run api "Waiting for the Kubernetes API server"
for attempt in $(seq 1 120); do
  kubectl get nodes > "$LOG_FILE" 2>&1 && break
  log "API server is not ready, retrying..."
  sleep 5
done
kubectl get nodes > "$LOG_FILE" 2>&1 || fail api "The Kubernetes API server did not become ready in 10 minutes" "$LOG_FILE"

echo "API server is ready"
progress 55 ok api "Kubernetes API server is ready"

#Run setup scripts, in the order of the questions (q2 before q10)
SETUP_SCRIPTS=()
while IFS= read -r script; do SETUP_SCRIPTS+=("$script"); done < <(ls /tmp/exam-assets/scripts/setup/q*_setup.sh 2>/dev/null | sort -V)
TOTAL=${#SETUP_SCRIPTS[@]}
INDEX=0
for script in "${SETUP_SCRIPTS[@]}"; do
  INDEX=$((INDEX + 1))
  QUESTION=$(basename "$script" | sed -E 's/^q([0-9]+)_setup\.sh$/\1/')
  STEP="q$QUESTION"
  progress $((55 + 44 * (INDEX - 1) / TOTAL)) run "$STEP" "Preparing question $QUESTION ($INDEX of $TOTAL)"
  run_logged "$LOG_FILE" "$script"
  RC=$?
  [ "$RC" -eq 0 ] || fail "$STEP" "The setup of question $QUESTION failed (exit code $RC)" "$LOG_FILE"
  progress $((55 + 44 * INDEX / TOTAL)) ok "$STEP" "Question $QUESTION is ready"
done

progress 100 ok ready "The exam environment is ready"
log "Exam environment preparation completed successfully"
exit 0 