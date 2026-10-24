#!/bin/bash
# Validate end to end that the ServiceAccount can create a normal Pod but not a privileged one
# in staging (server-side dry-run as the ServiceAccount: RBAC allows it, Pod Security refuses it)

NS="staging"
SA="system:serviceaccount:$NS:deployer-sa"

NORMAL=$(kubectl run ckx-sa-normal -n "$NS" --image=busybox:1.36.1 --restart=Never --dry-run=server --as "$SA" 2>&1)
if [ $? -ne 0 ]; then
  echo "❌ deployer-sa cannot create a normal Pod in '$NS': $(echo "$NORMAL" | head -1 | cut -c1-120)"
  exit 1
fi

PRIV=$(cat <<EOF
apiVersion: v1
kind: Pod
metadata: {name: ckx-sa-privileged, namespace: $NS}
spec:
  containers:
  - {name: c, image: busybox:1.36.1, securityContext: {privileged: true}}
EOF
)
OUT=$(echo "$PRIV" | kubectl apply --dry-run=server --as "$SA" -f - 2>&1)
if echo "$OUT" | grep -q "violates PodSecurity"; then
  echo "✅ deployer-sa can create a normal Pod but a privileged Pod is rejected by Pod Security"
  exit 0
fi

if echo "$OUT" | grep -qi "forbidden"; then
  echo "❌ The privileged Pod is rejected by RBAC, not by Pod Security: deployer-sa must be allowed to create Pods"
else
  echo "❌ deployer-sa can create a privileged Pod in '$NS'"
fi
exit 1
