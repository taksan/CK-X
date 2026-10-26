#!/bin/bash

# Setup for MHagou CKS exam 9, Question 1: secure the Docker daemon of the second worker node.
#
# The cluster runs containerd, so a small stand-in for the Docker daemon is installed on the second worker node
# (a systemd unit docker.service that runs /usr/local/sbin/dockerd). It behaves like the real
# daemon for what the question needs: it reads /etc/docker/daemon.json ("hosts", "group") when it
# starts, creates /var/run/docker.sock with that group and listens on the configured TCP hosts.
# User "developer" belongs to the group docker (and two other groups). The node restore removes
# everything again (the state file lists the users and groups that were created here).

source "$(dirname "$0")/../lib/nodes.sh"

NODE="$NODE02"

ssh -o StrictHostKeyChecking=no "$NODE" 'bash -s' <<'EOF'
set -e
systemctl stop docker 2>/dev/null || true
rm -f /var/run/docker.sock
STATE=/var/tmp/.ckx-q1-state
: > "$STATE"
for g in docker developers auditors; do
  getent group "$g" >/dev/null || { groupadd "$g"; echo "GROUP_$g" >> "$STATE"; }
done
if id developer >/dev/null 2>&1; then
  usermod -aG docker,developers,auditors developer
else
  useradd -m -s /bin/bash -G docker,developers,auditors developer
  echo "USER_developer" >> "$STATE"
fi

mkdir -p /etc/docker
cat > /etc/docker/daemon.json <<'JSON'
{
  "hosts": ["unix:///var/run/docker.sock", "tcp://0.0.0.0:2375"]
}
JSON

cat > /usr/local/sbin/dockerd <<'PY'
#!/usr/bin/python3
import json, os, socket, grp, signal, sys, threading

CFG = "/etc/docker/daemon.json"
cfg = {}
try:
    with open(CFG) as f:
        cfg = json.load(f)
except FileNotFoundError:
    pass
except Exception as exc:
    sys.stderr.write("unable to load %s: %s\n" % (CFG, exc))
    sys.exit(1)

hosts = cfg.get("hosts") or ["unix:///var/run/docker.sock"]
group = cfg.get("group", "docker")

def handle(conn):
    try:
        data = conn.recv(4096)
        line = data.split(b"\r\n")[0].decode(errors="replace")
        path = line.split(" ")[1] if " " in line else "/"
        status = b"200 OK"
        body = b"OK" if path.startswith("/_ping") else json.dumps({"Version": "lab", "Os": "linux"}).encode()
        if "/containers/" in path:
            # no container is ever known here: Falco (container plugin) asks about every container it sees and
            # crashes on a 200 answer that is not a container description
            status = b"404 Not Found"
            body = json.dumps({"message": "No such container"}).encode()
        head = b"HTTP/1.1 %s\r\nContent-Type: text/plain\r\nContent-Length: %d\r\nConnection: close\r\n\r\n" % (status, len(body))
        conn.sendall(head + body)
    except Exception:
        pass
    finally:
        conn.close()

def serve(sock):
    while True:
        conn, _ = sock.accept()
        threading.Thread(target=handle, args=(conn,), daemon=True).start()

unix_paths = []
for h in hosts:
    if h.startswith("unix://"):
        path = h[len("unix://"):]
        try:
            os.unlink(path)
        except FileNotFoundError:
            pass
        s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        s.bind(path)
        try:
            gid = grp.getgrnam(group).gr_gid
        except KeyError:
            sys.stderr.write("group %s not found\n" % group)
            sys.exit(1)
        os.chown(path, 0, gid)
        os.chmod(path, 0o660)
        unix_paths.append(path)
    elif h.startswith("tcp://"):
        host, port = h[len("tcp://"):].rsplit(":", 1)
        s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        s.bind((host, int(port)))
    else:
        continue
    s.listen(16)
    threading.Thread(target=serve, args=(s,), daemon=True).start()

def stop(*_):
    for p in unix_paths:
        try:
            os.unlink(p)
        except OSError:
            pass
    sys.exit(0)

signal.signal(signal.SIGTERM, stop)
signal.signal(signal.SIGINT, stop)
while True:
    signal.pause()
PY
chmod +x /usr/local/sbin/dockerd

cat > /etc/systemd/system/docker.service <<'UNIT'
[Unit]
Description=Docker Application Container Engine (lab stand-in)
After=network.target

[Service]
ExecStart=/usr/local/sbin/dockerd
Restart=on-failure

[Install]
WantedBy=multi-user.target
UNIT
systemctl daemon-reload
systemctl start docker
sleep 2
ss -ltn | grep -q ':2375 '
test "$(stat -c %G /var/run/docker.sock)" = docker
EOF

if [ $? -ne 0 ]; then
  echo "Failed to prepare the Docker daemon stand-in on $NODE"
  exit 1
fi

echo "Setup completed for MHagou exam 9 Question 1 (Docker daemon on $NODE)"
exit 0
