#!/bin/bash
# Source this file (question 2). token_mount_ok <json of a Deployment or Pod> <pod-spec jq path>
# succeeds when the object uses stats-monitor-sa and a projected volume named "token" with a
# serviceAccountToken source is mounted read-only so that the token ends up at
# /var/run/secrets/kubernetes.io/serviceaccount/token (any container, mount directory or subPath form).

token_mount_ok() {
  echo "$1" | jq -e "$2"' as $s | ($s.serviceAccountName == "stats-monitor-sa") and
    ([$s.volumes[]? | select(.name == "token") | .projected.sources[]? | select(.serviceAccountToken != null) | .serviceAccountToken.path] as $paths
     | ($paths | length) > 0
     and ([($s.containers[]?, $s.initContainers[]?) | .volumeMounts[]? | select(.name == "token" and (.readOnly == true) and (.subPathExpr // "") == "")
           | . as $m | $paths[] | . as $p
           | if ($m.subPath // "") == "" then (($m.mountPath | rtrimstr("/")) + "/" + $p)
             elif $p == $m.subPath then $m.mountPath
             elif ($p | startswith($m.subPath + "/")) then (($m.mountPath | rtrimstr("/")) + "/" + ($p | ltrimstr($m.subPath + "/")))
             else empty end]
          | index("/var/run/secrets/kubernetes.io/serviceaccount/token") != null))' >/dev/null 2>&1
}
