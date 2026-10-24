#!/bin/bash
# Validate etcd manifest has auto-tls=false and peer-auto-tls=false

NODE="k8s-api-server"
MANIFEST="/etc/kubernetes/manifests/etcd.yaml"

if ! ssh -o StrictHostKeyChecking=no "$NODE" "[ -f '$MANIFEST' ]" >/dev/null 2>&1; then
  echo "❌ etcd manifest not found at $MANIFEST on $NODE"
  exit 1
fi

CONTENT=$(ssh -o StrictHostKeyChecking=no "$NODE" "cat '$MANIFEST'" 2>/dev/null || true)

if echo "$CONTENT" | grep -q -- "--auto-tls=true"; then
  echo "❌ etcd manifest still has --auto-tls=true"
  exit 1
fi

if echo "$CONTENT" | grep -q -- "--peer-auto-tls=true"; then
  echo "❌ etcd manifest still has --peer-auto-tls=true"
  exit 1
fi

if ! echo "$CONTENT" | grep -q -- "--auto-tls=false"; then
  echo "❌ etcd manifest does not explicitly set --auto-tls=false"
  exit 1
fi

if ! echo "$CONTENT" | grep -q -- "--peer-auto-tls=false"; then
  echo "❌ etcd manifest does not explicitly set --peer-auto-tls=false"
  exit 1
fi

echo "✅ etcd manifest disables auto-tls and peer-auto-tls as required"
exit 0
