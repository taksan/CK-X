#!/bin/bash
# report.txt: process=<name of the process that the container spawns every few seconds>

source "$(dirname "$0")/../lib/report-q14.sh"
[ -n "$EXPECTED_PROCESS" ] || { echo "❌ Internal state file missing"; exit 1; }
V=$(report_value process)
[ -n "$V" ] || { echo "❌ $DIR/report.txt on $NODE has no 'process=' line"; exit 1; }
[ "$V" = "$EXPECTED_PROCESS" ] || { echo "❌ process=$V is not the process that the container spawns"; exit 1; }

echo "✅ The report names the process that the container spawns"
exit 0
