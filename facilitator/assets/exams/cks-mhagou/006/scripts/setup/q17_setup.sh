#!/bin/bash

# Setup for MHagou-006 Question 17: a container engine daemon that listens on TCP and a user in the
# docker group, on node02. Docker is not installed on the nodes, so the daemon is a small stand-in
# (python3) started by the systemd unit lab-docker.service with "-H unix://... -H tcp://0.0.0.0:2375".
# The user developer and the group docker are created here when they do not exist; the node restore
# stops the service and removes the unit, the user and the group (state in /var/tmp/.ckx-q17-state).

source "$(dirname "$0")/../lib/nodes.sh"

NODE="$NODE02"
SIM="$(dirname "$0")/../lib/dockerd-sim.py"

ssh -o StrictHostKeyChecking=no "$NODE" 'rm -rf /var/tmp/.ckx-lab && mkdir -p /var/tmp/.ckx-lab' || { echo "Failed to prepare $NODE"; exit 1; }
scp -q -o StrictHostKeyChecking=no "$SIM" "$NODE:/var/tmp/.ckx-lab/dockerd-sim.py" || { echo "Failed to copy the daemon to $NODE"; exit 1; }

ssh -o StrictHostKeyChecking=no "$NODE" 'bash -s' <<'EOF'
set -e
GROUP_CREATED=0; USER_CREATED=0
getent group docker >/dev/null || { groupadd docker; GROUP_CREATED=1; }
id developer >/dev/null 2>&1 || { useradd -m -s /bin/bash developer; USER_CREATED=1; }
usermod -aG docker developer
cat > /var/tmp/.ckx-q17-state <<STATE
Q17_GROUP_CREATED=$GROUP_CREATED
Q17_USER_CREATED=$USER_CREATED
STATE
cat > /etc/systemd/system/lab-docker.service <<UNIT
[Unit]
Description=Lab container engine daemon (stand-in)
After=network.target

[Service]
ExecStart=/usr/bin/python3 /var/tmp/.ckx-lab/dockerd-sim.py -H unix:///var/run/lab-docker.sock -H tcp://0.0.0.0:2375
Restart=on-failure

[Install]
WantedBy=multi-user.target
UNIT
systemctl daemon-reload
systemctl enable --now lab-docker.service >/dev/null 2>&1
for i in $(seq 1 15); do ss -ltn | grep -q ':2375 ' && break; sleep 1; done
ss -ltn | grep -q ':2375 '
EOF
[ $? -eq 0 ] || { echo "Failed to start the daemon on $NODE"; exit 1; }

echo "Setup completed for MHagou-006 Question 17 (daemon on ${NODE02}, user developer in the group docker)"
exit 0
