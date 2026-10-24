#!/bin/bash

# Setup for CKS-005 Question 10: ImagePolicyWebhook admission on the API server.
# Namespace image-policy is exclusive. On the control plane (k8s-api-server):
#   - a small HTTPS webhook backend (python3, 127.0.0.1:8443) that denies images tagged "latest"
#     or without a tag/digest and allows the others; it lives under /var/tmp/.ckx-webhook so the
#     node restore stops and removes it;
#   - the configuration files in /etc/kubernetes/policywebhook with three mistakes:
#       admission_config.json   kubeConfigFile points to a file that does not exist; defaultAllow true
#       kubeconfig.yaml         server URL with the wrong port (8444 instead of 8443)
#     and the API server itself knows nothing about the plugin yet.

source "$(dirname "$0")/../lib/wait-cluster.sh"

ensure_namespace image-policy

ssh -o StrictHostKeyChecking=no k8s-api-server 'bash -s' <<'EOF'
set -e
pkill -f '/var/tmp/\.ckx-webhook' 2>/dev/null || true
rm -rf /var/tmp/.ckx-webhook /etc/kubernetes/policywebhook
mkdir -p /var/tmp/.ckx-webhook /etc/kubernetes/policywebhook
cd /var/tmp/.ckx-webhook

openssl req -x509 -newkey rsa:2048 -nodes -days 3 -subj "/CN=image-policy-ca" -keyout ca.key -out /etc/kubernetes/policywebhook/ca.pem >/dev/null 2>&1
openssl req -newkey rsa:2048 -nodes -subj "/CN=image-policy-webhook" -keyout server.key -out server.csr >/dev/null 2>&1
printf 'subjectAltName=IP:127.0.0.1,DNS:localhost\n' > san.ext
openssl x509 -req -in server.csr -CA /etc/kubernetes/policywebhook/ca.pem -CAkey ca.key -CAcreateserial -days 3 -extfile san.ext -out server.crt >/dev/null 2>&1

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

cat > /etc/kubernetes/policywebhook/admission_config.json <<'JSON'
{
  "apiVersion": "apiserver.config.k8s.io/v1",
  "kind": "AdmissionConfiguration",
  "plugins": [
    {
      "name": "ImagePolicyWebhook",
      "configuration": {
        "imagePolicy": {
          "kubeConfigFile": "/etc/kubernetes/policywebhook/external-kubeconfig.yml",
          "allowTTL": 50,
          "denyTTL": 50,
          "retryBackoff": 500,
          "defaultAllow": true
        }
      }
    }
  ]
}
JSON

cat > /etc/kubernetes/policywebhook/kubeconfig.yaml <<'YAML'
apiVersion: v1
kind: Config
clusters:
- name: image-policy
  cluster:
    certificate-authority: /etc/kubernetes/policywebhook/ca.pem
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

echo "Setup completed for CKS-005 Question 10 (namespace image-policy, files in /etc/kubernetes/policywebhook on k8s-api-server)"
exit 0
