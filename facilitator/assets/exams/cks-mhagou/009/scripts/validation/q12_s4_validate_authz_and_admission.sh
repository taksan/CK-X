#!/bin/bash
# Item: authorization modes Node,RBAC and the NodeRestriction admission plugin are enabled

CMD=$(ssh -o StrictHostKeyChecking=no k8s-api-server "yq -o=json '.spec.containers[0].command' /etc/kubernetes/manifests/kube-apiserver.yaml" 2>/dev/null)
[ -n "$CMD" ] || { echo "❌ Unable to read the kube-apiserver manifest on the control plane"; exit 1; }

PLUGINS=$(echo "$CMD" | jq -r '[.[] | select(startswith("--enable-admission-plugins="))] | last // empty' | cut -d= -f2-)
echo ",$PLUGINS," | grep -q ',NodeRestriction,' \
  || { echo "❌ NodeRestriction is not in --enable-admission-plugins (found: '${PLUGINS:-<flag missing>}')"; exit 1; }

MODES=$(echo "$CMD" | jq -r '[.[] | select(startswith("--authorization-mode="))] | last // empty' | cut -d= -f2-)
SORTED=$(echo "$MODES" | tr ',' '\n' | sort | tr '\n' ',')
[ "$SORTED" = "Node,RBAC," ] || { echo "❌ The authorization modes are '${MODES:-<flag missing>}', expected Node,RBAC"; exit 1; }

echo "✅ Authorization modes Node,RBAC and the NodeRestriction admission plugin are configured"
exit 0
