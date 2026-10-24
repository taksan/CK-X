#!/bin/bash
# report.txt: image=<repository of the image of the container> (docker.io/library/busybox or busybox)

source "$(dirname "$0")/../lib/report-q14.sh"
[ -n "$EXPECTED_IMAGE" ] || { echo "❌ Internal state file missing"; exit 1; }
V=$(report_value image)
[ -n "$V" ] || { echo "❌ $DIR/report.txt on $NODE has no 'image=' line"; exit 1; }
N=$(echo "$V" | sed -E 's#^(docker\.io/)?(library/)?##; s#[:@].*$##')
[ "$N" = "$EXPECTED_IMAGE" ] || { echo "❌ image=$V is not the image repository of the container"; exit 1; }

echo "✅ The report has the image repository of the container"
exit 0
