#!/bin/bash
# Validate the ServiceAccount hidden-user exists in secret-room

kubectl get serviceaccount hidden-user -n secret-room >/dev/null 2>&1 \
  || { echo "❌ ServiceAccount 'hidden-user' not found in namespace 'secret-room'"; exit 1; }

echo "✅ ServiceAccount 'hidden-user' exists in secret-room"
exit 0
