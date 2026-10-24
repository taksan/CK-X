#!/bin/bash
# Validate RuntimeClass sandboxed exists with handler runsc

NAME="sandboxed"

if ! kubectl get runtimeclass "$NAME" >/dev/null 2>&1; then
  echo "❌ RuntimeClass '$NAME' not found"
  exit 1
fi

HANDLER=$(kubectl get runtimeclass "$NAME" -o jsonpath='{.handler}' 2>/dev/null || true)
if [ "$HANDLER" != "runsc" ]; then
  echo "❌ RuntimeClass '$NAME' does not use handler 'runsc' (current: $HANDLER)"
  exit 1
fi

echo "✅ RuntimeClass '$NAME' exists with handler 'runsc'"
exit 0
