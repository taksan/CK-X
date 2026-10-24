#!/bin/bash
# Validate the ServiceAccount backend-qa exists in qa

kubectl get serviceaccount backend-qa -n qa >/dev/null 2>&1 || { echo "❌ ServiceAccount 'backend-qa' not found in namespace 'qa'"; exit 1; }

echo "✅ ServiceAccount 'backend-qa' exists in 'qa'"
exit 0
