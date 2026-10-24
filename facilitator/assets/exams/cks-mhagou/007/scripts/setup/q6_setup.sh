#!/bin/bash

# Setup for MHAGOU-007 Question 6: a Docker-style daemon on node01 that is exposed on TCP and whose
# socket belongs to a group. The node has no Docker Engine (installing it would change the iptables
# of a Cilium node): the service dockerd-lab is a small program with the same configuration model:
# -H/--host flags or "hosts" in /etc/dockerd-lab/daemon.json (both together = refused start, as in
# dockerd), --group flag or "group" in daemon.json. The node restore removes everything it creates.

source "$(dirname "$0")/../lib/wait-cluster.sh"
source "$(dirname "$0")/../lib/nodes.sh"

ssh -o StrictHostKeyChecking=no node01 'bash -s' <<'EOF'
set -e
systemctl disable --now dockerd-lab.service >/dev/null 2>&1 || true
rm -rf /etc/systemd/system/dockerd-lab.service.d /etc/dockerd-lab
getent group docker >/dev/null || groupadd --system docker
mkdir -p /etc/dockerd-lab

cat > /usr/local/bin/dockerd-lab <<'PY'
#!/usr/bin/env python3
# minimal stand-in for dockerd: unix socket (owned by --group) and optional tcp listeners answering /_ping
import grp, json, os, socket, sys, threading

hosts, group, args = [], None, sys.argv[1:]
if os.path.exists("/run/dockerd-lab.sock"):
    os.unlink("/run/dockerd-lab.sock")   # no stale socket of a previous run
cfg_path = "/etc/dockerd-lab/daemon.json"
cfg = {}
if os.path.exists(cfg_path):
    try:
        cfg = json.load(open(cfg_path))
    except ValueError as e:
        sys.exit("unable to configure the daemon: invalid daemon.json: %s" % e)
i = 0
while i < len(args):
    a = args[i]
    if a in ("-H", "--host") and i + 1 < len(args):
        hosts.append(args[i + 1]); i += 2
    elif a.startswith("--host="):
        hosts.append(a.split("=", 1)[1]); i += 1
    elif a.startswith("-H") and len(a) > 2:
        hosts.append(a[2:]); i += 1
    elif a in ("-G", "--group") and i + 1 < len(args):
        group = args[i + 1]; i += 2
    elif a.startswith("--group="):
        group = a.split("=", 1)[1]; i += 1
    else:
        i += 1
if hosts and "hosts" in cfg:
    sys.exit("unable to configure the daemon: the following directives are specified both as a flag and in the configuration file: hosts: (from flag: %s, from file: %s)" % (hosts, cfg["hosts"]))
if group is not None and "group" in cfg:
    sys.exit("unable to configure the daemon: the following directives are specified both as a flag and in the configuration file: group")
hosts = hosts or cfg.get("hosts") or ["unix:///run/dockerd-lab.sock"]
group = group if group is not None else cfg.get("group", "docker")

def serve(sock):
    sock.listen(16)
    while True:
        c, _ = sock.accept()
        try:
            c.recv(1024)
            c.sendall(b"HTTP/1.1 200 OK\r\nContent-Length: 2\r\nConnection: close\r\n\r\nOK")
        finally:
            c.close()

for h in hosts:
    if h.startswith("unix://"):
        path = h[len("unix://"):]
        if os.path.exists(path):
            os.unlink(path)
        s = socket.socket(socket.AF_UNIX)
        s.bind(path)
        os.chown(path, 0, grp.getgrnam(group).gr_gid)
        os.chmod(path, 0o660)
    elif h.startswith("tcp://"):
        host, port = h[len("tcp://"):].rsplit(":", 1)
        s = socket.socket()
        s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        s.bind((host, int(port)))
    else:
        sys.exit("unsupported host %s" % h)
    threading.Thread(target=serve, args=(s,), daemon=True).start()
threading.Event().wait()
PY
chmod +x /usr/local/bin/dockerd-lab

cat > /etc/systemd/system/dockerd-lab.service <<'UNIT'
[Unit]
Description=Docker-style daemon of the lab (dockerd-lab)
After=network-online.target

[Service]
Type=simple
ExecStart=/usr/local/bin/dockerd-lab -H unix:///run/dockerd-lab.sock -H tcp://0.0.0.0:2375 --group=docker
Restart=always
RestartSec=2

[Install]
WantedBy=multi-user.target
UNIT
systemctl daemon-reload
systemctl enable --now dockerd-lab.service >/dev/null 2>&1
for i in 1 2 3 4 5; do ss -ltn 'sport = :2375' | grep -q 2375 && break; sleep 1; done
EOF

echo "Setup completed for MHAGOU-007 Question 6 (dockerd-lab.service on $NODE01)"
exit 0
