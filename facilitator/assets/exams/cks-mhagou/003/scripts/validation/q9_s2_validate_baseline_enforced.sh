#!/bin/bash
# Validate by behaviour (server-side dry-run) that the namespace enforces the Baseline standard:
# a privileged Pod is rejected by "baseline", a Pod that is only not restricted is accepted

kubectl get namespace secure-team >/dev/null 2>&1 || { echo "❌ Namespace 'secure-team' does not exist"; exit 1; }

priv() { cat <<EOF
apiVersion: v1
kind: Pod
metadata: {name: ckx-priv}
spec:
  containers: [{name: c, image: busybox:1.36.1, command: [sleep, "60"], securityContext: {privileged: true}}]
EOF
}
plain() { cat <<EOF
apiVersion: v1
kind: Pod
metadata: {name: ckx-plain}
spec:
  containers: [{name: c, image: busybox:1.36.1, command: [sleep, "60"]}]
EOF
}

OUT=$(priv | kubectl create -n secure-team --dry-run=server -f - 2>&1)
echo "$OUT" | grep -q 'violates PodSecurity "baseline' \
  || { echo "❌ A privileged Pod is not rejected by the baseline standard in secure-team (label pod-security.kubernetes.io/enforce=baseline)"; exit 1; }

OUT=$(plain | kubectl create -n secure-team --dry-run=server -f - 2>&1)
echo "$OUT" | grep -qi 'forbidden' && { echo "❌ A plain Pod (baseline compliant) is rejected in secure-team: the enforced level must be baseline, not restricted"; exit 1; }

echo "✅ secure-team enforces the baseline standard"
exit 0
