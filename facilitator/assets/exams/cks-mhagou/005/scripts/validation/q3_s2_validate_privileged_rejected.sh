#!/bin/bash
# Behaviour: Pod Security admission rejects a privileged Pod in api-security (server-side dry-run)

OUT=$(kubectl create -n api-security --dry-run=server -f - 2>&1 <<EOF
apiVersion: v1
kind: Pod
metadata: {name: ckx-priv-probe}
spec:
  containers: [{name: c, image: busybox:1.36.1, command: [sleep, "60"], securityContext: {privileged: true}}]
EOF
)
echo "$OUT" | grep -q 'violates PodSecurity "baseline' || { echo "❌ A privileged Pod is not rejected by Pod Security admission in api-security ($(echo "$OUT" | head -1 | cut -c1-120))"; exit 1; }

echo "✅ Pod Security admission rejects a privileged Pod in api-security"
exit 0
