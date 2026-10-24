#!/bin/bash

# Setup for MHagou-001 Question 1: ImagePolicyWebhook + NodeRestriction on the API server.
# Namespace webhook-lab is only used by the validators (dry-run probes).
#
# The source task blocks every new Pod with a dummy webhook ("it works when new Pods are refused").
# That would break the other questions of this exam, so here a small HTTPS backend runs on the control
# plane (python3, 127.0.0.1:8443, under /var/tmp/.ckx-webhook so the node restore stops and removes it):
# it denies images tagged "latest" (or without a tag) and allows the others. The webhook kubeconfig and
# its CA are prepared in /etc/kubernetes/admission; the candidate creates the AdmissionConfiguration
# (the setup writes it to /etc/kubernetes/admission/admission-config.yaml: the question gives the file, the work is to wire the API server) and wires the API server.
#
# Only this question changes the admission configuration of the API server (the flag is single valued).

source "$(dirname "$0")/../lib/wait-cluster.sh"
source "$(dirname "$0")/../lib/nodes.sh"

ensure_namespace webhook-lab

ssh -o StrictHostKeyChecking=no k8s-api-server 'bash -s' <<'EOF'
set -e
pkill -f '/var/tmp/\.ckx-webhook' 2>/dev/null || true
rm -rf /var/tmp/.ckx-webhook /etc/kubernetes/admission
mkdir -p /var/tmp/.ckx-webhook /etc/kubernetes/admission
cd /var/tmp/.ckx-webhook

openssl req -x509 -newkey rsa:2048 -nodes -days 3 -subj "/CN=image-policy-ca" -keyout ca.key -out /etc/kubernetes/admission/ca.pem >/dev/null 2>&1
openssl req -newkey rsa:2048 -nodes -subj "/CN=image-policy-webhook" -keyout server.key -out server.csr >/dev/null 2>&1
printf 'subjectAltName=IP:127.0.0.1,DNS:localhost\n' > san.ext
openssl x509 -req -in server.csr -CA /etc/kubernetes/admission/ca.pem -CAkey ca.key -CAcreateserial -days 3 -extfile san.ext -out server.crt >/dev/null 2>&1

cat > server.py <<'PY'
import json, ssl
from http.server import BaseHTTPRequestHandler, HTTPServer

def verdict(image):
    last = image.rsplit("/", 1)[-1]
    if "@sha256:" in image:
        return True
    if ":" not in last:
        return False
    return last.rsplit(":", 1)[1] != "latest"

class H(BaseHTTPRequestHandler):
    def do_POST(self):
        body = json.loads(self.rfile.read(int(self.headers.get("Content-Length", 0))) or b"{}")
        images = [c.get("image", "") for c in body.get("spec", {}).get("containers", [])]
        bad = [i for i in images if not verdict(i)]
        status = {"allowed": not bad}
        if bad:
            status["reason"] = "images must be pinned: " + ", ".join(bad)
        out = json.dumps({"apiVersion": body.get("apiVersion", "imagepolicy.k8s.io/v1alpha1"), "kind": "ImageReview", "status": status}).encode()
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(out)))
        self.end_headers()
        self.wfile.write(out)
    def log_message(self, *a):
        pass

ctx = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
ctx.load_cert_chain("/var/tmp/.ckx-webhook/server.crt", "/var/tmp/.ckx-webhook/server.key")
srv = HTTPServer(("127.0.0.1", 8443), H)
srv.socket = ctx.wrap_socket(srv.socket, server_side=True)
srv.serve_forever()
PY
nohup setsid python3 /var/tmp/.ckx-webhook/server.py >/dev/null 2>&1 < /dev/null &

cat > /etc/kubernetes/admission/webhook.kubeconfig <<'YAML'
apiVersion: v1
kind: Config
clusters:
- name: image-policy
  cluster:
    certificate-authority: /etc/kubernetes/admission/ca.pem
    server: https://127.0.0.1:8443/image_policy
contexts:
- name: image-policy
  context:
    cluster: image-policy
    user: api-server
current-context: image-policy
users:
- name: api-server
  user: {}
YAML
cat > /etc/kubernetes/admission/admission-config.yaml <<'YAML2'
apiVersion: apiserver.config.k8s.io/v1
kind: AdmissionConfiguration
plugins:
- name: ImagePolicyWebhook
  configuration:
    imagePolicy:
      kubeConfigFile: /etc/kubernetes/admission/webhook.kubeconfig
      allowTTL: 50
      denyTTL: 50
      retryBackoff: 500
      defaultAllow: false
YAML2
sleep 1
EOF

echo "Setup completed for MHagou-001 Question 1 (webhook backend and kubeconfig prepared on $CONTROL_PLANE)"
exit 0
