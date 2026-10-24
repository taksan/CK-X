#!/bin/bash
# Validate by behaviour: the RUNNING API server answers requests without credentials to the API
# endpoints with HTTP 401 (the new configuration is really in use after the restart)

SERVER=$(kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}' 2>/dev/null)
[ -n "$SERVER" ] || { echo "❌ Unable to read the API server address from the kubeconfig"; exit 1; }

code() { curl -sk --noproxy '*' -m 5 -o /dev/null -w '%{http_code}' "$SERVER$1" 2>/dev/null; }

# the API server needs about a minute to restart after a manifest change
for i in $(seq 1 30); do
  [ "$(code /api)" = "401" ] && break
  sleep 4
done

for path in /api /apis /version; do
  c=$(code "$path")
  if [ "$c" != "401" ]; then
    echo "❌ GET $path without credentials returned HTTP ${c:-none}, expected 401 (is anonymous access still open in the running API server?)"
    exit 1
  fi
done

echo "✅ Requests without credentials get HTTP 401 on /api, /apis and /version"
exit 0
