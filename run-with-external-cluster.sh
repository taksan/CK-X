#!/usr/bin/env bash

# ===============================================================================
#  Start CK-X against an existing (e.g. kubeadm) cluster instead of k3d.
#
#  - flattens the kubeconfig when it references external cert/key files
#  - validates the API server, the nodes and (optionally) the SSH directory
#  - starts docker compose with the "external-cluster" profile
#
#  Usage:
#    ./run-with-external-cluster.sh --kubeconfig <file> [--ssh-dir <dir>] [--no-build] [--dry-run]
#    ./run-with-external-cluster.sh EXTERNAL_KUBECONFIG=<file> EXTERNAL_SSH_DIR=<dir>
#
#  The SSH directory holds an ssh "config" (host aliases such as node01,
#  node02, k8s-api-server) and the pre-authorized private keys.
# ===============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GENERATED_DIR="$SCRIPT_DIR/.external"

KUBECONFIG_ARG=""
SSH_DIR_ARG=""
BUILD=true
DRY_RUN=false

log()  { echo "[$(date '+%H:%M:%S')] $*"; }
ok()   { echo "  ✓ $*"; }
warn() { echo "  ⚠ $*" >&2; }
die()  { echo "  ✗ $*" >&2; exit 1; }

usage() {
  sed -n '4,16p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,2\}//'
}

expand_path() {
  case "$1" in
    "~") echo "$HOME" ;;
    "~/"*) echo "$HOME/${1#~/}" ;;
    *) echo "$1" ;;
  esac
}

# ------------------------------------------------------------------------------
# Arguments
# ------------------------------------------------------------------------------
while [ $# -gt 0 ]; do
  case "$1" in
    --kubeconfig)  [ $# -ge 2 ] || die "--kubeconfig needs a value"; KUBECONFIG_ARG="$2"; shift 2 ;;
    --ssh-dir)     [ $# -ge 2 ] || die "--ssh-dir needs a value"; SSH_DIR_ARG="$2"; shift 2 ;;
    EXTERNAL_KUBECONFIG=*) KUBECONFIG_ARG="${1#*=}"; shift ;;
    EXTERNAL_SSH_DIR=*)    SSH_DIR_ARG="${1#*=}"; shift ;;
    --no-build)    BUILD=false; shift ;;
    --dry-run)     DRY_RUN=true; shift ;;
    -h|--help)     usage; exit 0 ;;
    *) usage >&2; die "Unknown argument: $1" ;;
  esac
done

[ -n "$KUBECONFIG_ARG" ] || { usage >&2; die "A kubeconfig is required (--kubeconfig <file>)"; }

KUBECONFIG_SRC="$(expand_path "$KUBECONFIG_ARG")"
[ -f "$KUBECONFIG_SRC" ] || die "Kubeconfig not found: $KUBECONFIG_SRC"
KUBECONFIG_SRC="$(cd "$(dirname "$KUBECONFIG_SRC")" && pwd)/$(basename "$KUBECONFIG_SRC")"

SSH_DIR=""
if [ -n "$SSH_DIR_ARG" ]; then
  SSH_DIR="$(expand_path "$SSH_DIR_ARG")"
  [ -d "$SSH_DIR" ] || die "SSH directory not found: $SSH_DIR"
  SSH_DIR="$(cd "$SSH_DIR" && pwd)"
fi

# ------------------------------------------------------------------------------
# Tools
# ------------------------------------------------------------------------------
log "Checking required tools"
command -v docker  >/dev/null 2>&1 || die "docker is not installed"
docker compose version >/dev/null 2>&1 || die "docker compose plugin is not available"
command -v kubectl >/dev/null 2>&1 || die "kubectl is not installed"
[ -z "$SSH_DIR" ] || command -v ssh >/dev/null 2>&1 || die "ssh is not installed"
ok "docker, docker compose, kubectl"

# ------------------------------------------------------------------------------
# Kubeconfig: flatten when it references files outside itself
# ------------------------------------------------------------------------------
log "Checking kubeconfig: $KUBECONFIG_SRC"
EXTERNAL_KUBECONFIG="$KUBECONFIG_SRC"

if grep -Eq '^[[:space:]]*(certificate-authority|client-certificate|client-key|tokenFile):' "$KUBECONFIG_SRC"; then
  mkdir -p "$GENERATED_DIR"
  chmod 700 "$GENERATED_DIR"
  FLAT="$GENERATED_DIR/kubeconfig"
  ( umask 077; kubectl config view --flatten --minify --raw --kubeconfig "$KUBECONFIG_SRC" > "$FLAT" ) \
    || die "Could not flatten the kubeconfig"
  if grep -Eq '^[[:space:]]*(certificate-authority|client-certificate|client-key|tokenFile):' "$FLAT"; then
    die "Flattened kubeconfig still references external files"
  fi
  EXTERNAL_KUBECONFIG="$FLAT"
  ok "Kubeconfig references external files: flattened to $FLAT"
else
  ok "Kubeconfig is self-contained, no flattening needed"
fi

# ------------------------------------------------------------------------------
# Cluster validation
# ------------------------------------------------------------------------------
kc() { kubectl --kubeconfig "$EXTERNAL_KUBECONFIG" --request-timeout=15s "$@"; }

log "Validating the cluster"
SERVER="$(kc config view --minify -o jsonpath='{.clusters[0].cluster.server}')"
[ -n "$SERVER" ] || die "No cluster server found in the kubeconfig"

HOST_PORT="${SERVER#*://}"; HOST_PORT="${HOST_PORT%%/*}"
API_HOST="${HOST_PORT%:*}"
API_PORT="${HOST_PORT##*:}"; [ "$API_PORT" != "$HOST_PORT" ] || API_PORT=443

case "$API_HOST" in
  127.*|localhost|::1|"[::1]")
    die "API server is '$SERVER': it is not reachable from the containers. Use an address reachable from Docker." ;;
esac
ok "API server: $SERVER"

NODES_OUT="$(kc get nodes --no-headers 2>&1)" || die "Cannot list nodes: $NODES_OUT"
TOTAL=$(echo "$NODES_OUT" | grep -c . || true)
READY=$(echo "$NODES_OUT" | awk '$2 == "Ready"' | grep -c . || true)
[ "$READY" -ge 1 ] || die "No Ready nodes in the cluster"
if [ "$READY" -lt "$TOTAL" ]; then
  warn "$((TOTAL - READY)) of $TOTAL nodes are not Ready"
fi
ok "$READY/$TOTAL nodes Ready"
echo "$NODES_OUT" | awk '{printf "      %-24s %-10s %-16s %s\n", $1, $2, $3, $5}'

WORKERS=$(echo "$NODES_OUT" | awk '$3 !~ /control-plane/' | grep -c . || true)
[ "$WORKERS" -ge 1 ] || warn "No worker nodes found: exams with workerNodes >= 1 may not schedule"

kc auth can-i create namespaces >/dev/null 2>&1 \
  && ok "Credentials can create namespaces" \
  || die "The kubeconfig user cannot create namespaces (cluster-admin is expected)"

log "Checking that Docker containers can reach $API_HOST:$API_PORT"
if docker run --rm alpine:3.20 nc -z -w 5 "$API_HOST" "$API_PORT" >/dev/null 2>&1; then
  ok "Reachable from a Docker container"
else
  die "A Docker container cannot reach $API_HOST:$API_PORT"
fi

# ------------------------------------------------------------------------------
# SSH directory validation
# ------------------------------------------------------------------------------
if [ -n "$SSH_DIR" ]; then
  log "Validating SSH directory: $SSH_DIR"
  SSH_CONFIG="$SSH_DIR/config"
  [ -f "$SSH_CONFIG" ] || die "No 'config' file in $SSH_DIR"

  # the jumphost keeps keys in ~/.ssh, so IdentityFile paths are resolved by file name
  TMP_CONFIG="$(mktemp)"
  trap 'rm -f "$TMP_CONFIG"' EXIT
  sed -E "s#^([[:space:]]*IdentityFile[[:space:]]+)(.*/)?([^/[:space:]]+)[[:space:]]*\$#\\1$SSH_DIR/\\3#" \
    "$SSH_CONFIG" > "$TMP_CONFIG"

  KEYS=$(awk 'tolower($1)=="identityfile" {print $2}' "$TMP_CONFIG" | sort -u)
  [ -n "$KEYS" ] || warn "The ssh config does not define any IdentityFile"
  for key in $KEYS; do
    [ -f "$key" ] || die "IdentityFile '$(basename "$key")' referenced by the config is not in $SSH_DIR"
  done

  ALIASES=$(awk 'tolower($1)=="host" { for (i = 2; i <= NF; i++) if ($i !~ /[*?!]/) print $i }' "$SSH_CONFIG")
  [ -n "$ALIASES" ] || die "No Host aliases found in the ssh config"

  FAILED=0
  for alias in $ALIASES; do
    if ssh -F "$TMP_CONFIG" -o IdentitiesOnly=yes -o BatchMode=yes -o ConnectTimeout=8 \
           -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR \
           "$alias" 'test "$(id -u)" = 0' >/dev/null 2>&1; then
      ok "ssh $alias works as root"
    else
      warn "ssh $alias failed (or the user is not root)"
      FAILED=$((FAILED + 1))
    fi
  done
  [ "$FAILED" -eq 0 ] || die "$FAILED SSH host(s) are not usable"
else
  warn "No --ssh-dir given: questions that edit node files will not work"
fi

# ------------------------------------------------------------------------------
# Start
# ------------------------------------------------------------------------------
export EXTERNAL_KUBECONFIG
[ -z "$SSH_DIR" ] || export EXTERNAL_SSH_DIR="$SSH_DIR"

UP_ARGS=(--profile external-cluster up -d --remove-orphans)
$BUILD && UP_ARGS+=(--build)

log "docker compose ${UP_ARGS[*]}"
log "  EXTERNAL_KUBECONFIG=$EXTERNAL_KUBECONFIG"
[ -z "$SSH_DIR" ] || log "  EXTERNAL_SSH_DIR=$EXTERNAL_SSH_DIR"

if $DRY_RUN; then
  log "Dry run: not starting docker compose"
  exit 0
fi

cd "$SCRIPT_DIR"
# The kubeconfig loader is a one-shot container. When the compose network was recreated (a prune, a
# change of the compose file) the exited loader still points at the old network and "up" fails with
# "network ... not found": remove it, compose creates it again.
docker compose --profile external-cluster rm -sf external-kubeconfig >/dev/null 2>&1 || true
docker compose "${UP_ARGS[@]}"

log "Done. Open http://localhost:30080 and start the exam."
log "To go back to k3d: docker compose down --volumes"
