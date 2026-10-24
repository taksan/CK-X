#!/bin/bash
# Item: the Deployment projects the token into a volume named token, read-only, at the required path

source "$(dirname "$0")/../lib/projected-token.sh"

J=$(kubectl get deployment stats-monitor -n monitoring -o json 2>/dev/null)
[ -n "$J" ] || { echo "❌ Deployment stats-monitor not found in namespace monitoring"; exit 1; }

if ! token_mount_ok "$J" '.spec.template.spec'; then
  echo "❌ The Deployment must use stats-monitor-sa and mount a projected serviceAccountToken volume named 'token' read-only so that the token is at /var/run/secrets/kubernetes.io/serviceaccount/token"
  exit 1
fi

echo "✅ The Deployment projects the token (volume 'token') read-only at /var/run/secrets/kubernetes.io/serviceaccount/token"
exit 0
