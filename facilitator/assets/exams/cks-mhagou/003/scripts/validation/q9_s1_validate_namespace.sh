#!/bin/bash
# Validate the namespace secure-team exists and is Active

PHASE=$(kubectl get namespace secure-team -o jsonpath='{.status.phase}' 2>/dev/null)
[ "$PHASE" = "Active" ] || { echo "❌ Namespace 'secure-team' does not exist or is not Active (phase: ${PHASE:-absent})"; exit 1; }

echo "✅ Namespace secure-team exists and is Active"
exit 0
