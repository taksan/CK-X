#!/bin/bash

# Setup for MHagou CKS exam 9, Question 6: complete the ImagePolicyWebhook integration.
# Namespace scanner-lab is exclusive (the validators create dry-run Pods there). On the control plane
# (k8s-api-server):
#   - a small HTTPS "image scanner" (python3, 127.0.0.1:8081, path /image_policy) that rejects the
#     vulnerable fixture nginx:1.16 and admits other images; it runs from /var/tmp/.ckx-scanner (the
#     node restore stops and removes it) and wakanda.local is mapped to 127.0.0.1 in /etc/hosts
#     (a line marked "# ckx-mhagou009", removed by the node restore);
#   - an incomplete configuration in /etc/kubernetes/epconfig (tracked path, restored):
#       admission-config.yaml   defaultAllow: true
#       webhook.kubeconfig      server .../incomplete (wrong path)
#     and the API server does not use any of it yet.

source "$(dirname "$0")/../lib/wait-cluster.sh"

ensure_namespace scanner-lab

ssh -o StrictHostKeyChecking=no k8s-api-server 'bash -s' <<'EOF'
set -e
pkill -f '/var/tmp/\.ckx-scanner' 2>/dev/null || true
rm -rf /var/tmp/.ckx-scanner /etc/kubernetes/epconfig
mkdir -p /var/tmp/.ckx-scanner /etc/kubernetes/epconfig
sed -i '/# ckx-mhagou009/d' /etc/hosts
echo "127.0.0.1 wakanda.local # ckx-mhagou009" >> /etc/hosts
cd /var/tmp/.ckx-scanner

openssl req -x509 -newkey rsa:2048 -nodes -days 3 -subj "/CN=scanner-ca" -keyout ca.key -out /etc/kubernetes/epconfig/webhook.pem >/dev/null 2>&1
openssl req -newkey rsa:2048 -nodes -subj "/CN=wakanda.local" -keyout server.key -out server.csr >/dev/null 2>&1
printf 'subjectAltName=DNS:wakanda.local,IP:127.0.0.1\n' > san.ext
openssl x509 -req -in server.csr -CA /etc/kubernetes/epconfig/webhook.pem -CAkey ca.key -CAcreateserial -days 3 -extfile san.ext -out server.crt >/dev/null 2>&1

cat > server.py <<'PY'
import json, ssl
from http.server import BaseHTTPRequestHandler, HTTPServer

VULNERABLE = {"nginx:1.16", "docker.io/library/nginx:1.16"}

class H(BaseHTTPRequestHandler):
    def do_POST(self):
        if not self.path.startswith("/image_policy"):
            self.send_response(404)
            self.end_headers()
            return
        body = json.loads(self.rfile.read(int(self.headers.get("Content-Length", 0))) or b"{}")
        images = [c.get("image", "") for c in body.get("spec", {}).get("containers", [])]
        bad = [i for i in images if i in VULNERABLE]
        status = {"allowed": not bad}
        if bad:
            status["reason"] = "image scanner: vulnerable image " + ", ".join(bad)
        out = json.dumps({"apiVersion": body.get("apiVersion", "imagepolicy.k8s.io/v1alpha1"), "kind": "ImageReview", "status": status}).encode()
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(out)))
        self.end_headers()
        self.wfile.write(out)
    def log_message(self, *a):
        pass

ctx = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
ctx.load_cert_chain("/var/tmp/.ckx-scanner/server.crt", "/var/tmp/.ckx-scanner/server.key")
srv = HTTPServer(("127.0.0.1", 8081), H)
srv.socket = ctx.wrap_socket(srv.socket, server_side=True)
srv.serve_forever()
PY
nohup setsid python3 /var/tmp/.ckx-scanner/server.py >/dev/null 2>&1 < /dev/null &

cat > /etc/kubernetes/epconfig/admission-config.yaml <<'YAML'
apiVersion: apiserver.config.k8s.io/v1
kind: AdmissionConfiguration
plugins:
- name: ImagePolicyWebhook
  configuration:
    imagePolicy:
      kubeConfigFile: /etc/kubernetes/epconfig/webhook.kubeconfig
      allowTTL: 50
      denyTTL: 50
      retryBackoff: 500
      defaultAllow: true
YAML

cat > /etc/kubernetes/epconfig/webhook.kubeconfig <<'YAML'
apiVersion: v1
kind: Config
clusters:
- name: bouncer_webhook
  cluster:
    certificate-authority: /etc/kubernetes/epconfig/webhook.pem
    server: https://wakanda.local:8081/incomplete
contexts:
- name: bouncer_webhook
  context:
    cluster: bouncer_webhook
    user: api-server
current-context: bouncer_webhook
users:
- name: api-server
  user: {}
YAML
sleep 1
EOF

echo "Setup completed for MHagou exam 9 Question 6 (namespace scanner-lab, files in /etc/kubernetes/epconfig on k8s-api-server)"
exit 0
