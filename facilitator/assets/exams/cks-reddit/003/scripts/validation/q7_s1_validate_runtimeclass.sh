#!/bin/bash
# Validate RuntimeClass untrusted exists with handler runsc

HANDLER=$(kubectl get runtimeclass untrusted -o jsonpath='{.handler}' 2>/dev/null)
if [ -z "$HANDLER" ]; then
  echo "❌ RuntimeClass 'untrusted' not found"
  exit 1
fi

if [ "$HANDLER" != "runsc" ]; then
  echo "❌ RuntimeClass 'untrusted' does not use the handler 'runsc' (current: $HANDLER)"
  exit 1
fi

echo "✅ RuntimeClass 'untrusted' exists with handler 'runsc'"
exit 0
