#!/bin/bash
# report.txt: uid=<numeric user id of that process>

source "$(dirname "$0")/../lib/report-q14.sh"
[ -n "$EXPECTED_UID" ] || { echo "❌ Internal state file missing"; exit 1; }
V=$(report_value uid)
[ -n "$V" ] || { echo "❌ $DIR/report.txt on $NODE has no 'uid=' line"; exit 1; }
[ "$V" = "$EXPECTED_UID" ] || { echo "❌ uid=$V is not the numeric user id of the process in the container"; exit 1; }

echo "✅ The report has the numeric uid of the process"
exit 0
