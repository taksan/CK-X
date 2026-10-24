#!/bin/bash

# Setup for MHagou-003 Question 4: ImagePolicyWebhook admission on the API server.
# Namespace image-gate is exclusive. On the control plane (k8s-api-server):
#   - a small HTTPS webhook backend (python3, 127.0.0.1:8443) that denies the images whose repository
#     is under "untrusted/" and allows every other image; it lives under /var/tmp/.ckx-webhook so
#     that the node restore stops and removes it;
#   - /etc/kubernetes/admission/{admission_config.yaml,kubeconf,ca.pem}. The configuration is
#     fail-closed (defaultAllow: false) but kubeconf points to the wrong port (8444) and the API
#     server does not know the plugin yet.
# This is the ONLY question of the exam that uses --admission-control-config-file; the backend
# allows every normal image so that the other questions keep working once the plugin is enabled.

source "$(dirname "$0")/../lib/wait-cluster.sh"
source "$(dirname "$0")/../lib/nodes.sh"

ensure_namespace image-gate

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

def allowed(image):
    # deny the repositories under "untrusted/" (docker.io/untrusted/app:1.0, registry.example.org/untrusted/x, untrusted/y)
    path = image.split("@", 1)[0]
    parts = path.split("/")
    return "untrusted" not in parts[:-1]

class H(BaseHTTPRequestHandler):
    def do_POST(self):
        body = json.loads(self.rfile.read(int(self.headers.get("Content-Length", 0))) or b"{}")
        images = [c.get("image", "") for c in body.get("spec", {}).get("containers", [])]
        bad = [i for i in images if not allowed(i)]
        status = {"allowed": not bad}
        if bad:
            status["reason"] = "images from untrusted repositories are not allowed: " + ", ".join(bad)
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

cat > /etc/kubernetes/admission/admission_config.yaml <<'YAML'
apiVersion: apiserver.config.k8s.io/v1
kind: AdmissionConfiguration
plugins:
- name: ImagePolicyWebhook
  configuration:
    imagePolicy:
      kubeConfigFile: /etc/kubernetes/admission/kubeconf
      allowTTL: 50
      denyTTL: 50
      retryBackoff: 500
      defaultAllow: false
YAML

cat > /etc/kubernetes/admission/kubeconf <<'YAML'
apiVersion: v1
kind: Config
clusters:
- name: image-policy
  cluster:
    certificate-authority: /etc/kubernetes/admission/ca.pem
    server: https://127.0.0.1:8444/image_policy
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
sleep 1
EOF

echo "Setup completed for MHagou-003 Question 4 (namespace image-gate, files in /etc/kubernetes/admission on ${CONTROL_PLANE})"
exit 0
