#!/bin/bash
# Validate Pod Security enforcement in staging by behaviour: a privileged Pod is rejected by
# the Pod Security admission, a normal Pod is accepted (server-side dry-run, nothing is created).

NS="staging"

LEVEL=$(kubectl get namespace "$NS" -o jsonpath='{.metadata.labels.pod-security\.kubernetes\.io/enforce}' 2>/dev/null)
if [ "$LEVEL" != "baseline" ] && [ "$LEVEL" != "restricted" ]; then
  echo "❌ Namespace '$NS' does not enforce the baseline (or restricted) Pod Security Standard (enforce='$LEVEL')"
  exit 1
fi

PRIV=$(cat <<EOF
apiVersion: v1
kind: Pod
metadata: {name: ckx-privileged-check, namespace: $NS}
spec:
  containers:
  - {name: c, image: busybox:1.36.1, securityContext: {privileged: true}}
EOF
)
OUT=$(echo "$PRIV" | kubectl apply --dry-run=server -f - 2>&1)
if ! echo "$OUT" | grep -q "violates PodSecurity"; then
  echo "❌ A privileged Pod is not rejected by Pod Security in '$NS'"
  exit 1
fi

if ! kubectl run ckx-normal-check -n "$NS" --image=busybox:1.36.1 --restart=Never --dry-run=server >/dev/null 2>&1; then
  echo "❌ A normal Pod is rejected in '$NS' (the standard is too strict or the namespace is broken)"
  exit 1
fi

echo "✅ '$NS' enforces Pod Security: privileged Pods are rejected, normal Pods are accepted"
exit 0
