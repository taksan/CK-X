#!/bin/bash
# Item (by behaviour): the container of secure-nginx is confined by the Localhost profile secure-profile
# (enforce mode, read from the process on node01: the profile denies the busybox tools of the image, so it
# cannot be read from inside) and the profile is really effective (the programs the container starts are denied)

NS="secured-area"
J=$(kubectl get pod secure-nginx -n "$NS" -o json 2>/dev/null)
[ -n "$J" ] || { echo "❌ Pod 'secure-nginx' not found in namespace '$NS'"; exit 1; }
[ "$(echo "$J" | jq -r '.status.phase')" = "Running" ] || { echo "❌ secure-nginx is not running"; exit 1; }

# the field can be set on the Pod, on the container, or with the (older) annotation
if ! echo "$J" | jq -e '
      (.spec.securityContext.appArmorProfile | (.type == "Localhost" and .localhostProfile == "secure-profile"))
      or all(.spec.containers[]; .securityContext.appArmorProfile | (.type == "Localhost" and .localhostProfile == "secure-profile"))
      or any(.metadata.annotations // {} | to_entries[]; (.key | startswith("container.apparmor.security.beta.kubernetes.io/")) and .value == "localhost/secure-profile")' >/dev/null; then
  echo "❌ The Pod does not select the Localhost AppArmor profile secure-profile"
  exit 1
fi

CUR=$(ssh -o StrictHostKeyChecking=no node01 'bash -s' <<'EOF' 2>/dev/null | tr -d '\000'
export CONTAINER_RUNTIME_ENDPOINT=unix:///run/containerd/containerd.sock
CID=$(crictl ps --state running --label io.kubernetes.pod.name=secure-nginx --label io.kubernetes.pod.namespace=secured-area -q 2>/dev/null | head -1)
PID=$(crictl inspect "$CID" 2>/dev/null | jq -r '.info.pid // empty')
[ -n "$PID" ] && cat /proc/$PID/attr/current
EOF
)
[ "$CUR" = "secure-profile (enforce)" ] || { echo "❌ The container process is confined by '${CUR:-no profile}', expected 'secure-profile (enforce)'"; exit 1; }

# The first process of an exec is not checked by the profile (it is started before the profile applies), the
# programs it starts are: a child process (ls is a busybox applet) must be denied
if kubectl exec -n "$NS" secure-nginx -- /bin/sh -c '/bin/ls /' >/dev/null 2>&1; then
  echo "❌ A process of the container can still run busybox programs (ls): the profile is not effective"
  exit 1
fi

echo "✅ secure-nginx is confined by secure-profile (enforce): the busybox programs are denied"
exit 0
