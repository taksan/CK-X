#!/bin/bash
# Validate etcd: client certificate authentication on and auto-tls off

NODE="k8s-api-server"
MANIFEST="/etc/kubernetes/manifests/etcd.yaml"

CONTENT=$(ssh -o StrictHostKeyChecking=no "$NODE" "cat '$MANIFEST'" 2>/dev/null)
if [ -z "$CONTENT" ]; then
  echo "❌ etcd manifest not found at $MANIFEST on $NODE"
  exit 1
fi

if echo "$CONTENT" | grep -q -- '--client-cert-auth=false' || ! echo "$CONTENT" | grep -q -- '--client-cert-auth=true'; then
  echo "❌ etcd does not enforce client certificate authentication (--client-cert-auth=true)"
  exit 1
fi

if echo "$CONTENT" | grep -q -- '--auto-tls=true'; then
  echo "❌ etcd still has --auto-tls=true"
  exit 1
fi

if ! echo "$CONTENT" | grep -q -- '--auto-tls=false'; then
  echo "❌ etcd does not explicitly set --auto-tls=false"
  exit 1
fi

# and etcd is really running with it
CMD=$(kubectl get pods -n kube-system -l component=etcd -o jsonpath='{.items[0].spec.containers[0].command}' 2>/dev/null)
if ! echo "$CMD" | grep -q -- '--client-cert-auth=true"'; then
  echo "❌ The running etcd Pod does not use --client-cert-auth=true yet"
  exit 1
fi

echo "✅ etcd enforces client certificate authentication and has auto-tls disabled"
exit 0
