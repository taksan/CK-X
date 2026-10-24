#!/bin/bash
# RuntimeClass not-trusted selects the handler runsc

H=$(kubectl get runtimeclass not-trusted -o jsonpath='{.handler}' 2>/dev/null)
[ -n "$H" ] || { echo "❌ RuntimeClass 'not-trusted' not found"; exit 1; }
[ "$H" = "runsc" ] || { echo "❌ RuntimeClass 'not-trusted' uses the handler '$H', expected runsc"; exit 1; }

echo "✅ RuntimeClass 'not-trusted' uses the handler runsc"
exit 0
