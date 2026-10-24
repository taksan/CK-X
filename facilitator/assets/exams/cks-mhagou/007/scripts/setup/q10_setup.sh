#!/bin/bash

# Setup for MHAGOU-007 Question 10: Cilium network policies. Namespaces data-tier (database pods),
# web-tier (backend and frontend), outside-lab (a backend-labelled Pod of another namespace) and dev-clients
# (the env=dev clients with an initial egress deny) are exclusive. Every Pod echoes on TCP 3306, 8080, 53 and
# UDP 53. No Cilium policy exists at the start.

source "$(dirname "$0")/../lib/wait-cluster.sh"
source "$(dirname "$0")/../lib/nodes.sh"

for ns in data-tier web-tier outside-lab dev-clients; do ensure_namespace "$ns"; done
kubectl delete ciliumnetworkpolicies --all -A >/dev/null 2>&1 || true
for ns in data-tier web-tier outside-lab dev-clients; do kubectl delete networkpolicy --all -n "$ns" >/dev/null 2>&1; done

make_pod() { # ns name app env node
  kubectl apply -f - >/dev/null <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: $2
  namespace: $1
  labels:
    app: $3
    env: $4
spec:
  nodeName: $5
  automountServiceAccountToken: false
  containers:
  - name: probe
    image: python:3.12-alpine
    command: [python3, -u, -c]
    args:
    - |
      import socket, threading, time
      def tcp(port):
          s = socket.socket()
          s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
          s.bind(('0.0.0.0', port)); s.listen()
          while True:
              c, _ = s.accept()
              c.settimeout(2)
              try: c.sendall(c.recv(1024))
              except OSError: pass
              finally: c.close()
      def udp():
          s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
          s.bind(('0.0.0.0', 53))
          while True:
              data, addr = s.recvfrom(2048); s.sendto(data, addr)
      for port in (3306, 8080, 53):
          threading.Thread(target=tcp, args=(port,), daemon=True).start()
      threading.Thread(target=udp, daemon=True).start()
      while True: time.sleep(3600)
    readinessProbe:
      tcpSocket: {port: 3306}
      initialDelaySeconds: 2
      periodSeconds: 2
    resources:
      requests: {cpu: 10m, memory: 24Mi}
      limits: {memory: 96Mi}
EOF
}

make_pod data-tier cks-db database test "$NODE01"
make_pod data-tier cks-db-peer peer test "$NODE02"
make_pod web-tier cks-backend backend test "$NODE02"
make_pod web-tier cks-frontend frontend test "$NODE01"
make_pod outside-lab cks-outsider backend test "$NODE02"
make_pod dev-clients cks-dev dev-client dev "$NODE01"
make_pod dev-clients cks-dev-other other-client dev "$NODE02"

# a denied initial API connection makes the entity policy observable (allows nothing, no solution in it)
kubectl apply -f - >/dev/null <<EOF
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: dev-initial-deny
  namespace: dev-clients
spec:
  podSelector:
    matchLabels:
      env: dev
  policyTypes: [Egress]
  egress: []
EOF

for ns in data-tier web-tier outside-lab dev-clients; do
  kubectl wait pod --all -n "$ns" --for=condition=Ready --timeout=240s >/dev/null || { echo "WARNING: pods of $ns are not ready"; exit 1; }
done

echo "Setup completed for MHAGOU-007 Question 10 (namespaces data-tier, web-tier, outside-lab, dev-clients)"
exit 0
