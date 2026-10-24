#!/bin/bash
# RuntimeClass hardened exists and uses the handler runsc (gVisor)

H=$(kubectl get runtimeclass hardened -o jsonpath='{.handler}' 2>/dev/null)
[ -n "$H" ] || { echo "❌ RuntimeClass 'hardened' not found"; exit 1; }
[ "$H" = "runsc" ] || { echo "❌ RuntimeClass 'hardened' uses the handler '$H', expected runsc"; exit 1; }

echo "✅ RuntimeClass 'hardened' uses the handler runsc"
exit 0
