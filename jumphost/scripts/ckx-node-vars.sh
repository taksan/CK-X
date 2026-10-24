#!/bin/bash
#
# ckx-node-vars: the names that the Kubernetes cluster gives to its nodes, as the exams need them.
#
# The exams do not know the names of the nodes of the cluster they run on. They talk about the first and the
# second worker node (NODE01, NODE02) and the control plane (CONTROL_PLANE); this script maps them to the
# real node names. The ssh aliases k8s-api-server, node01 and node02 (the ssh directory of the cluster) say
# which machine is which: the node whose address (or name) is the HostName of the alias is that node. When
# an alias is missing or matches no node, the workers are taken in alphabetical order.
#
#   ckx-node-vars --env     prints: export NODE01=... NODE02=... CONTROL_PLANE=...
#   ckx-node-vars --json    prints: {"NODE01": "...", "NODE02": "...", "CONTROL_PLANE": "..."}
#   ckx-node-vars --write   writes ckx-vars.env and ckx-vars.json in the kube directory (default
#                           /home/candidate/.kube, override with CKX_VARS_DIR) and prints the env form
#
# Variables of the environment override the discovery: NODE01, NODE02, CONTROL_PLANE.

set -o pipefail

MODE="${1:---env}"
VARS_DIR="${CKX_VARS_DIR:-/home/candidate/.kube}"
[ -z "${KUBECONFIG:-}" ] && [ -f /home/candidate/.kube/kubeconfig ] && export KUBECONFIG=/home/candidate/.kube/kubeconfig

discover() {
  local nodes
  nodes="$(kubectl --request-timeout=15s get nodes -o json 2>/dev/null)" || nodes=""
  python3 - "$nodes" <<'PY'
import json, os, subprocess, sys

raw = sys.argv[1]
out = {"NODE01": "node01", "NODE02": "node02", "CONTROL_PLANE": "k8s-api-server"}   # defaults: the lab cluster

def alias_host(alias):
    try:
        res = subprocess.run(["ssh", "-G", alias], capture_output=True, text=True, timeout=10)
        for line in res.stdout.splitlines():
            if line.startswith("hostname "):
                host = line.split(None, 1)[1].strip()
                return None if host == alias else host
    except Exception:
        pass
    return None

try:
    items = json.loads(raw)["items"]
except Exception:
    items = []

if items:
    def addresses(n):
        a = {x["address"] for x in n["status"].get("addresses", [])}
        a.add(n["metadata"]["name"])
        return a

    def is_cp(n):
        labels = n["metadata"].get("labels", {})
        return "node-role.kubernetes.io/control-plane" in labels or "node-role.kubernetes.io/master" in labels

    def ready(n):
        return any(c["type"] == "Ready" and c["status"] == "True" for c in n["status"].get("conditions", []))

    cps = sorted([n for n in items if is_cp(n)], key=lambda n: n["metadata"]["name"])
    workers = sorted([n for n in items if not is_cp(n)], key=lambda n: (not ready(n), n["metadata"]["name"]))

    host = alias_host("k8s-api-server")
    cp = next((n for n in cps if host and host in addresses(n)), cps[0] if cps else None)
    if cp:
        out["CONTROL_PLANE"] = cp["metadata"]["name"]

    taken = set()
    chosen = {}
    for key, alias in (("NODE01", "node01"), ("NODE02", "node02")):
        host = alias_host(alias)
        match = next((n for n in workers if host and host in addresses(n) and n["metadata"]["name"] not in taken), None)
        if match:
            chosen[key] = match["metadata"]["name"]
            taken.add(match["metadata"]["name"])
    rest = [n["metadata"]["name"] for n in workers if n["metadata"]["name"] not in taken]
    for key in ("NODE01", "NODE02"):
        if key not in chosen and rest:
            chosen[key] = rest.pop(0)
    out.update(chosen)

for key in ("NODE01", "NODE02", "CONTROL_PLANE"):
    if os.environ.get(key):
        out[key] = os.environ[key]
print(json.dumps(out))
PY
}

JSON="$(discover)"
[ -n "$JSON" ] || JSON='{"NODE01": "node01", "NODE02": "node02", "CONTROL_PLANE": "k8s-api-server"}'
ENV_TEXT="$(printf '%s' "$JSON" | python3 -c 'import json,sys; d=json.load(sys.stdin); print("export NODE01=%s NODE02=%s CONTROL_PLANE=%s" % (d["NODE01"], d["NODE02"], d["CONTROL_PLANE"]))')"

case "$MODE" in
  --json) echo "$JSON" ;;
  --env)  echo "$ENV_TEXT" ;;
  --write)
    mkdir -p "$VARS_DIR"
    printf '%s\n' "$JSON" > "$VARS_DIR/ckx-vars.json"
    printf '%s\n' "$ENV_TEXT" > "$VARS_DIR/ckx-vars.env"
    chmod 644 "$VARS_DIR/ckx-vars.json" "$VARS_DIR/ckx-vars.env"
    echo "$ENV_TEXT" ;;
  *) echo "usage: ckx-node-vars --env|--json|--write" >&2; exit 2 ;;
esac
