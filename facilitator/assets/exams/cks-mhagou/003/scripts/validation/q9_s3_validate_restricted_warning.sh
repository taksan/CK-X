#!/bin/bash
# Validate by behaviour that violations of the Restricted standard produce a warning (not a rejection)

kubectl get namespace secure-team >/dev/null 2>&1 || { echo "❌ Namespace 'secure-team' does not exist"; exit 1; }

OUT=$(kubectl create -n secure-team --dry-run=server -f - 2>&1 <<EOF
apiVersion: v1
kind: Pod
metadata: {name: ckx-plain}
spec:
  containers: [{name: c, image: busybox:1.36.1, command: [sleep, "60"]}]
EOF
)
echo "$OUT" | grep -qi 'forbidden' && { echo "❌ A baseline-compliant Pod is rejected: the restricted standard must only warn (label pod-security.kubernetes.io/warn=restricted)"; exit 1; }
echo "$OUT" | grep -q 'would violate PodSecurity "restricted' \
  || { echo "❌ No warning about the restricted standard for a Pod that violates it (label pod-security.kubernetes.io/warn=restricted)"; exit 1; }

echo "✅ secure-team warns about Restricted violations"
exit 0
