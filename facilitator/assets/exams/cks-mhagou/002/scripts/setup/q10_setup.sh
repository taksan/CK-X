#!/bin/bash

# Setup for MHAGOU-002 Question 10: ImagePolicyWebhook admission on the API server.
# Namespace image-review is exclusive (probe namespace of the validators). On the control plane
# (k8s-api-server):
#   - a small HTTPS webhook backend (python3, 127.0.0.1:8443) that denies the images of the registry
#     untrusted.example.com and allows every other image; it lives under /var/tmp/.ckx-webhook so
#     the node restore stops and removes it. It is deliberately narrow: the other questions of the
#     exam keep creating Pods with ordinary images (nginx, busybox ...) after this one is solved;
#   - /etc/kubernetes/pki/admission_configuration.yaml and admission_kube_config.yaml with the mistakes
#     of the source task: kubeConfigFile points to a file that does not exist (.yml instead of
#     .yaml) and defaultAllow is true; the API server knows nothing about the plugin yet.
# /etc/kubernetes/pki is already mounted into the kube-apiserver Pod (k8s-certs): the files are
# visible there, no extra volume is needed.

source "$(dirname "$0")/../lib/wait-cluster.sh"
source "$(dirname "$0")/../lib/nodes.sh"

ensure_namespace image-review

ssh -o StrictHostKeyChecking=no k8s-api-server 'bash -s' <<'EOF'
set -e
pkill -f '/var/tmp/\.ckx-webhook' 2>/dev/null || true
rm -rf /var/tmp/.ckx-webhook /etc/kubernetes/pki/admission_configuration.yaml /etc/kubernetes/pki/admission_kube_config.yaml /etc/kubernetes/pki/admission_ca.pem
mkdir -p /var/tmp/.ckx-webhook
cd /var/tmp/.ckx-webhook

openssl req -x509 -newkey rsa:2048 -nodes -days 3 -subj "/CN=image-review-ca" -keyout ca.key -out /etc/kubernetes/pki/admission_ca.pem >/dev/null 2>&1
openssl req -newkey rsa:2048 -nodes -subj "/CN=image-review-backend" -keyout server.key -out server.csr >/dev/null 2>&1
printf 'subjectAltName=IP:127.0.0.1,DNS:localhost\n' > san.ext
openssl x509 -req -in server.csr -CA /etc/kubernetes/pki/admission_ca.pem -CAkey ca.key -CAcreateserial -days 3 -extfile san.ext -out server.crt >/dev/null 2>&1

cat > server.py <<'PY'
import json, ssl
from http.server import BaseHTTPRequestHandler, HTTPServer

DENIED_REGISTRY = "untrusted.example.com/"

class H(BaseHTTPRequestHandler):
    def do_POST(self):
        body = json.loads(self.rfile.read(int(self.headers.get("Content-Length", 0))) or b"{}")
        images = [c.get("image", "") for c in body.get("spec", {}).get("containers", [])]
        bad = [i for i in images if i.startswith(DENIED_REGISTRY)]
        status = {"allowed": not bad}
        if bad:
            status["reason"] = "images from an untrusted registry: " + ", ".join(bad)
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

cat > /etc/kubernetes/pki/admission_configuration.yaml <<'YAML'
apiVersion: apiserver.config.k8s.io/v1
kind: AdmissionConfiguration
plugins:
- name: ImagePolicyWebhook
  configuration:
    imagePolicy:
      kubeConfigFile: /etc/kubernetes/pki/admission_kube_config.yml
      allowTTL: 50
      denyTTL: 50
      retryBackoff: 500
      defaultAllow: true
YAML

cat > /etc/kubernetes/pki/admission_kube_config.yaml <<'YAML'
apiVersion: v1
kind: Config
clusters:
- name: image-review
  cluster:
    certificate-authority: /etc/kubernetes/pki/admission_ca.pem
    server: https://127.0.0.1:8443/image_policy
contexts:
- name: image-review
  context:
    cluster: image-review
    user: api-server
current-context: image-review
users:
- name: api-server
  user: {}
YAML
chmod 600 /etc/kubernetes/pki/admission_configuration.yaml /etc/kubernetes/pki/admission_kube_config.yaml
sleep 1
EOF

echo "Setup completed for MHAGOU-002 Question 10 (namespace image-review, files in /etc/kubernetes/pki on ${CONTROL_PLANE})"
exit 0
