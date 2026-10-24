#!/bin/bash
# Validate a Pod that follows the Restricted standard is accepted without warnings
# (credited only when the namespace carries pod security labels: the fresh namespace does not exist)

kubectl get namespace secure-team >/dev/null 2>&1 || { echo "❌ Namespace 'secure-team' does not exist"; exit 1; }
LABELS=$(kubectl get namespace secure-team -o json | jq -c '[.metadata.labels // {} | keys[] | select(startswith("pod-security.kubernetes.io/"))] | length')
[ "${LABELS:-0}" -ge 1 ] || { echo "❌ The namespace has no pod-security.kubernetes.io labels yet"; exit 1; }

OUT=$(kubectl create -n secure-team --dry-run=server -f - 2>&1 <<EOF
apiVersion: v1
kind: Pod
metadata: {name: ckx-restricted}
spec:
  securityContext:
    runAsNonRoot: true
    runAsUser: 10001
    seccompProfile: {type: RuntimeDefault}
  containers:
  - name: c
    image: busybox:1.36.1
    command: [sleep, "60"]
    securityContext:
      allowPrivilegeEscalation: false
      capabilities: {drop: ["ALL"]}
EOF
)
echo "$OUT" | grep -qi 'forbidden\|error' && { echo "❌ A Restricted-compliant Pod is rejected: $(echo "$OUT" | head -1 | cut -c1-160)"; exit 1; }
echo "$OUT" | grep -qi 'would violate' && { echo "❌ A Restricted-compliant Pod produces a PodSecurity warning: $(echo "$OUT" | head -1 | cut -c1-160)"; exit 1; }

echo "✅ A Restricted-compliant Pod is accepted without warnings"
exit 0
