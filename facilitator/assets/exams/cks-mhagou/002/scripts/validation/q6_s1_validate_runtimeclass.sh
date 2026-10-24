#!/bin/bash
# The RuntimeClass runsc-class exists with the handler runsc

H=$(kubectl get runtimeclass runsc-class -o jsonpath='{.handler}' 2>/dev/null)
[ -n "$H" ] || { echo "❌ RuntimeClass 'runsc-class' not found"; exit 1; }
[ "$H" = "runsc" ] || { echo "❌ RuntimeClass 'runsc-class' has the handler '$H', expected runsc"; exit 1; }
echo "✅ RuntimeClass runsc-class uses the handler runsc"
exit 0
