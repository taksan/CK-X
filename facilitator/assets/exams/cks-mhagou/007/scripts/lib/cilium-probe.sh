#!/bin/bash
# Source this file (question 10). probe NS POD HOST PORT [tcp|udp|api|dns-udp|dns-tcp]: exit 0 when the exchange
# works, 42 when the connection fails, other codes for a probe error. allowed / denied wrap it with a retry
# for the policy convergence (allowed: retried; denied: a first success is retried after a pause).

probe() {
  local ns=$1 pod=$2 host=$3 port=$4 mode=${5:-tcp}
  kubectl -n "$ns" exec -i "$pod" -- python3 - "$host" "$port" "$mode" <<'PY'
import socket, sys, struct, ssl
host, port, mode = sys.argv[1], int(sys.argv[2]), sys.argv[3]
try:
    s = socket.socket(socket.AF_INET6 if ':' in host else socket.AF_INET,
                      socket.SOCK_DGRAM if mode in ('udp', 'dns-udp') else socket.SOCK_STREAM)
    s.settimeout(3); s.connect((host, port))
    if mode == 'api':
        s = ssl._create_unverified_context().wrap_socket(s, server_hostname='kubernetes')
        s.sendall(b'GET /version HTTP/1.0\r\nHost: kubernetes\r\n\r\n')
        if not s.recv(1024).startswith(b'HTTP/'): sys.exit(43)
    elif mode.startswith('dns-'):
        q = b'\x45\x67\x01\x00\x00\x01\x00\x00\x00\x00\x00\x00' + b'\x0akubernetes\x07default\x03svc\x07cluster\x05local\x00\x00\x01\x00\x01'
        s.sendall(struct.pack('!H', len(q)) + q if mode == 'dns-tcp' else q)
        data = s.recv(4096)
        if mode == 'dns-tcp':
            while len(data) < 14:
                chunk = s.recv(4096)
                if not chunk: sys.exit(43)
                data += chunk
            data = data[2:]
        if len(data) < 12 or data[:2] != q[:2] or not (data[2] & 128): sys.exit(43)
    else:
        s.sendall(b'cks-probe')
        if s.recv(32) != b'cks-probe': sys.exit(43)
except (OSError, ssl.SSLError):
    sys.exit(42)
PY
}

# allowed DESCRIPTION NS POD HOST PORT [MODE]: returns 0 when allowed (retries for the policy convergence)
allowed() {
  local rc=0; shift
  probe "$@" >/dev/null 2>&1 && return 0
  sleep 3; probe "$@" >/dev/null 2>&1
}

# denied NS POD HOST PORT [MODE]: returns 0 only for a real connection failure (exit 42)
denied() {
  local rc=0
  probe "$@" >/dev/null 2>&1 || rc=$?
  [ "$rc" = "42" ]
}

cilium_fixtures_ready() {
  local pair
  for pair in 'data-tier cks-db' 'data-tier cks-db-peer' 'web-tier cks-backend' 'web-tier cks-frontend' 'outside-lab cks-outsider' 'dev-clients cks-dev' 'dev-clients cks-dev-other'; do
    set -- $pair
    kubectl -n "$1" wait "pod/$2" --for=condition=Ready --timeout=10s >/dev/null 2>&1 || { echo "❌ Test fixture $1/$2 is not running (do not delete the provided workloads)"; return 1; }
  done
}

pod_ip() { kubectl -n "$1" get pod "$2" -o jsonpath='{.status.podIP}' 2>/dev/null; }
