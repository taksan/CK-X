#!/bin/bash
# Validate sa-name.txt holds the ServiceAccount used by nginx-pod

F="${Q13_FILE:-/tmp/exam/cks-005-q13/sa-name.txt}"
[ -s "$F" ] || { echo "❌ $F does not exist or is empty"; exit 1; }
SA=$(kubectl get pod nginx-pod -n test-system -o jsonpath='{.spec.serviceAccountName}' 2>/dev/null)
[ "$(tr -d '[:space:]' < "$F")" = "$SA" ] && [ -n "$SA" ] || { echo "❌ $F does not contain the ServiceAccount of nginx-pod"; exit 1; }

echo "✅ sa-name.txt holds the ServiceAccount of nginx-pod"
exit 0
