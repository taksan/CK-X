#!/bin/bash
# The ServiceAccount seminar-sa exists in the namespace seminar

if [ -z "$(kubectl get serviceaccount seminar-sa -n seminar -o name 2>/dev/null)" ]; then
  echo "❌ ServiceAccount 'seminar-sa' not found in namespace 'seminar'"
  exit 1
fi
echo "✅ ServiceAccount seminar-sa exists"
exit 0
