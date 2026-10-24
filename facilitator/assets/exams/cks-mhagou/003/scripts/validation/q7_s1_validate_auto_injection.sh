#!/bin/bash
# Validate by behaviour: a NEW Pod created in restricted-zone gets an Istio proxy automatically
# (server-side dry-run runs the mutating webhooks; nothing is created)

NS="restricted-zone"
LABELS=$(kubectl get namespace "$NS" -o json 2>/dev/null | jq -c '.metadata.labels // {}')
echo "$LABELS" | jq -e '(.["istio-injection"] == "enabled") or ((.["istio.io/rev"] // "") != "")' >/dev/null \
  || { echo "❌ Sidecar injection is not enabled in namespace '$NS' (label istio-injection=enabled)"; exit 1; }

OUT=$(kubectl create -n "$NS" --dry-run=server -o json -f - 2>/dev/null <<EOF
apiVersion: v1
kind: Pod
metadata: {name: ckx-probe}
spec:
  containers: [{name: c, image: "busybox:1.36.1", command: [sleep, "60"]}]
EOF
)
echo "$OUT" | jq -e '[.spec.containers[]?.name, .spec.initContainers[]?.name] | index("istio-proxy") != null' >/dev/null \
  || { echo "❌ A new Pod in '$NS' does not get an istio-proxy container (is the Istio injection webhook answering for this namespace?)"; exit 1; }

echo "✅ New Pods in $NS get an Istio sidecar automatically"
exit 0
