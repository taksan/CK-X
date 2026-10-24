#!/bin/bash
# Item: kube-apiserver enables ImagePolicyWebhook AND NodeRestriction and points to an admission configuration
# file (read from the manifest on the control plane)

source "$(dirname "$0")/../lib/apiserver.sh"

CMD=$(apiserver_command_json)
[ -n "$CMD" ] || { echo "❌ Unable to read the kube-apiserver manifest on the control plane"; exit 1; }

PLUGINS=$(apiserver_flag enable-admission-plugins)
echo ",$PLUGINS," | grep -q ',ImagePolicyWebhook,' || { echo "❌ ImagePolicyWebhook is not in --enable-admission-plugins (found: ${PLUGINS:-none})"; exit 1; }
echo ",$PLUGINS," | grep -q ',NodeRestriction,' || { echo "❌ NodeRestriction is not in --enable-admission-plugins (found: $PLUGINS)"; exit 1; }

FILE=$(apiserver_flag admission-control-config-file)
[ -n "$FILE" ] || { echo "❌ kube-apiserver has no --admission-control-config-file flag"; exit 1; }

echo "✅ ImagePolicyWebhook and NodeRestriction are enabled and the configuration file is $FILE"
exit 0
