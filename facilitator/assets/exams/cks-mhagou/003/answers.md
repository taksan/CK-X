# CKS - MHagou - Exam 3 - Answer key

Source: `mhagou/exam-3` (ten labs), adapted to the three-node kubeadm cluster of the lab
(`{{CONTROL_PLANE}}`, `{{NODE01}}`, `{{NODE02}}`). Every command below was run against the lab cluster.
Questions 1 and 4 both edit the kube-apiserver manifest (different flags): do them one after the other and
keep what the other one changed.

---

## Question 1: anonymous authentication (kube-apiserver)

The plain flag `--anonymous-auth=false` makes the kubelet probes of the kube-apiserver Pod (`/livez`, `/readyz` without
credentials) fail with 401: the Pod never becomes Ready and is restarted again and again (verified on the lab cluster).
The structured authentication configuration disables anonymous access except for chosen paths:

```bash
ssh {{CONTROL_PLANE}}
cat > /etc/kubernetes/auth-config.yaml <<'EOF'
apiVersion: apiserver.config.k8s.io/v1
kind: AuthenticationConfiguration
anonymous:
  enabled: true
  conditions:
  - path: /livez
  - path: /readyz
  - path: /healthz
EOF
vi /etc/kubernetes/manifests/kube-apiserver.yaml
```

```yaml
    - --authentication-config=/etc/kubernetes/auth-config.yaml
    ...
    volumeMounts:
    - {name: auth-config, mountPath: /etc/kubernetes/auth-config.yaml, readOnly: true}
  volumes:
  - name: auth-config
    hostPath: {path: /etc/kubernetes/auth-config.yaml, type: File}
```

Wait about a minute for the static Pod to restart, then check from the jumphost:

```bash
curl -sk -o /dev/null -w '%{http_code}\n' https://<api-server>:6443/api      # 401
curl -sk -o /dev/null -w '%{http_code}\n' https://<api-server>:6443/livez    # 200
kubectl -n kube-system get pod -l component=kube-apiserver                    # 1/1 Running, restarts not growing
```

`--authentication-config` cannot be combined with `--anonymous-auth` (the API server refuses to start): do not keep the flag.

## Question 2: Cilium mutual authentication (`cilium-lab`)

```bash
kubectl apply -f - <<'EOF'
apiVersion: cilium.io/v2
kind: CiliumNetworkPolicy
metadata: {name: nginx-auth, namespace: cilium-lab}
spec:
  endpointSelector: {matchLabels: {app: nginx}}
  ingress:
  - fromEndpoints:
    - matchLabels: {app: curlpod}
    toPorts:
    - ports: [{port: "80", protocol: TCP}]
    authentication:
      mode: required
EOF
kubectl -n cilium-lab exec curlpod -- wget -qO- http://nginx          # works
kubectl -n cilium-lab exec other -- wget -T3 -qO- http://nginx        # denied
kubectl -n kube-system exec ds/cilium -- cilium-dbg bpf auth list     # a "spire" entry for the two identities
```

The ingress rule is what makes everything else to `nginx` denied; the handshake needs the SPIRE server of the lab.

## Question 3: Falco rule for `/dev/mem` (`{{NODE01}}`)

```bash
ssh {{NODE01}}
cat >> /etc/falco/falco_rules.local.yaml <<'EOF'
- rule: Detect dev mem access
  desc: Detect any attempt to open /dev/mem
  condition: fd.name = "/dev/mem"
  output: "Sensitive file opened (user=%user.name command=%proc.cmdline file=%fd.name)"
  priority: WARNING
EOF
systemctl restart falco-modern-bpf      # Falco also reloads the rules by itself (watch_config_files)
journalctl -u falco-modern-bpf -f       # see the alerts
```

Trigger it with a Pod on `{{NODE01}}` that opens the device (a privileged container sees `/dev/mem`; for a harmless
test mount any file at that path):

```bash
kubectl -n memory-watch apply -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata: {name: mem-reader}
spec:
  nodeName: {{NODE01}}
  containers:
  - name: c
    image: busybox:1.36.1
    command: ["sh", "-c", "while true; do cat /dev/mem >/dev/null; sleep 5; done"]
    securityContext: {privileged: true}
EOF
```

Pitfalls: a condition such as `fd.name startswith /dev/mem` also matches `/dev/mem2`; the rule file must be valid YAML
(an invalid file leaves Falco without rules); Falco evaluates the rules with `rule_matching: first`.

## Question 4: ImagePolicyWebhook (kube-apiserver)

```bash
ssh {{CONTROL_PLANE}}
cd /etc/kubernetes/admission
cat admission_config.yaml kubeconf           # the kubeconf server uses the port 8444, the backend listens on 8443
sed -i 's#8444#8443#' kubeconf
vi /etc/kubernetes/manifests/kube-apiserver.yaml
```

```yaml
    - --enable-admission-plugins=NodeRestriction,ImagePolicyWebhook
    - --admission-control-config-file=/etc/kubernetes/admission/admission_config.yaml
    ...
    volumeMounts:
    - {name: admission, mountPath: /etc/kubernetes/admission, readOnly: true}
  volumes:
  - name: admission
    hostPath: {path: /etc/kubernetes/admission, type: DirectoryOrCreate}
```

`defaultAllow: false` is already set (fail closed). Wait for the API server, then:

```bash
kubectl run t --image=docker.io/untrusted/app:1.0 -n image-gate --dry-run=server     # denied by the image policy webhook
kubectl run t --image=nginx:1.27 -n image-gate --dry-run=server                      # accepted
```

If the API server never comes back, `crictl ps -a` / `crictl logs` on the control plane show the plugin error (for
example a wrong path of the configuration file). With a wrong port and `defaultAllow: false` it starts, but every
Pod (including the mirror Pods of the static Pods) is rejected.

## Question 5: kubesec (`kubesec-lab`)

```bash
kubesec scan /tmp/exam/mhagou-003-q5/pod.yaml | jq '.[0] | {score, advise: [.scoring.advise[].id]}'
```

Improved manifest (score 15; only AppArmor and `hostUsers` are missing):

```yaml
apiVersion: v1
kind: Pod
metadata: {name: web, namespace: kubesec-lab}
spec:
  automountServiceAccountToken: false
  serviceAccountName: web-sa              # kubectl -n kubesec-lab create serviceaccount web-sa
  securityContext:
    runAsNonRoot: true
    runAsUser: 20000
    runAsGroup: 20000
    seccompProfile: {type: RuntimeDefault}
  containers:
  - name: web
    image: nginxinc/nginx-unprivileged:1.27-alpine
    resources:
      requests: {cpu: 50m, memory: 64Mi}
      limits: {cpu: 200m, memory: 128Mi}
    securityContext:
      allowPrivilegeEscalation: false
      readOnlyRootFilesystem: true
      capabilities: {drop: ["ALL"]}
    volumeMounts:
    - {name: tmp, mountPath: /tmp}        # the image writes its temporary files there
  volumes:
  - {name: tmp, emptyDir: {}}
```

```bash
kubectl apply -f /tmp/exam/mhagou-003-q5/pod.yaml
kubesec scan /tmp/exam/mhagou-003-q5/pod.yaml | jq '.[0].score'
```

## Question 6: mesh-wide STRICT mTLS (`hello-mesh`, `mesh-client`)

```bash
kubectl apply -f - <<'EOF'
apiVersion: security.istio.io/v1
kind: PeerAuthentication
metadata: {name: default, namespace: istio-system}
spec:
  mtls:
    mode: STRICT
EOF
kubectl -n mesh-client exec client -- curl -sI http://helloworld.hello-mesh.svc.cluster.local:5000/hello    # connection reset
kubectl label namespace mesh-client istio-injection=enabled --overwrite
kubectl -n mesh-client delete pod client
kubectl -n mesh-client run client --image=curlimages/curl:8.10.1 --command -- sleep 86400
kubectl -n mesh-client exec client -c client -- curl -s http://helloworld.hello-mesh.svc.cluster.local:5000/hello
```

The policy in `istio-system` (the mesh root namespace) without a selector applies to the whole mesh. A Pod is
injected only when it is created, so the existing Pod has to be recreated after the label.

## Question 7: sidecar injection and namespace STRICT mTLS (`restricted-zone`)

```bash
kubectl label namespace restricted-zone istio-injection=enabled
kubectl -n restricted-zone rollout restart deployment payment-service
kubectl apply -f - <<'EOF'
apiVersion: security.istio.io/v1
kind: PeerAuthentication
metadata: {name: default, namespace: restricted-zone}
spec:
  mtls:
    mode: STRICT
EOF
kubectl -n legacy-zone exec legacy -- curl -s -m5 http://payment-service.restricted-zone:8000/get       # fails
kubectl -n restricted-zone run sleep --image=curlimages/curl:8.10.1 --command -- sleep 3600
kubectl -n restricted-zone exec sleep -c sleep -- curl -s http://payment-service:8000/get               # works
```

## Question 8: SPDX SBOM

```bash
trivy image --format spdx-json --output /tmp/exam/mhagou-003-q8/sbom.spdx nginx:1.19
# or: trivy image --format spdx --output /tmp/exam/mhagou-003-q8/sbom.spdx nginx:1.19
jq '.name, (.packages | length)' /tmp/exam/mhagou-003-q8/sbom.spdx
```

## Question 9: Pod Security Standards and seccomp (`secure-team`)

```bash
kubectl create namespace secure-team
kubectl label namespace secure-team pod-security.kubernetes.io/enforce=baseline pod-security.kubernetes.io/warn=restricted
kubectl apply -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata: {name: nginx-secure, namespace: secure-team}
spec:
  securityContext:
    seccompProfile: {type: Localhost, localhostProfile: profiles/audit.json}
  containers:
  - {name: nginx, image: nginx}
EOF
```

The profile `/var/lib/kubelet/seccomp/profiles/audit.json` (on both workers) logs every syscall (`SCMP_ACT_LOG`); the
process of the Pod runs in seccomp filter mode (`grep Seccomp /proc/1/status` shows `Seccomp: 2`). A Pod that is baseline
compliant but not restricted compliant is accepted with a warning.

## Question 10: projected ServiceAccount tokens (`token-lab`)

```bash
kubectl apply -f - <<'EOF'
apiVersion: v1
kind: Secret
metadata:
  name: token-bot-secret
  namespace: token-lab
  annotations:
    kubernetes.io/service-account.name: token-bot
type: kubernetes.io/service-account-token
---
apiVersion: v1
kind: Pod
metadata: {name: token-pod, namespace: token-lab}
spec:
  serviceAccountName: token-bot
  automountServiceAccountToken: false
  containers:
  - name: nginx
    image: nginx:alpine
    volumeMounts:
    - {name: tokens, mountPath: /var/run/secrets/custom-tokens, readOnly: true}
  volumes:
  - name: tokens
    projected:
      sources:
      - secret:
          name: token-bot-secret
          items: [{key: token, path: secret-token}]
      - serviceAccountToken:
          path: short-token
          expirationSeconds: 3600
EOF
kubectl -n token-lab exec token-pod -- ls -l /var/run/secrets/custom-tokens
```

---

## Deviations from the source labs

- Q1: **adapted.** The source asked for `--anonymous-auth=false`; on this kubeadm cluster that flag leaves the API server
  not Ready (the kubelet probes are anonymous), so the question asks for the supported way: an AuthenticationConfiguration
  that keeps the health endpoints anonymous. The source supported k3s too.
- Q2: **replaced.** The source enabled WireGuard encryption with a Helm upgrade of Cilium, which cannot be done (or undone) by an
  exam on a shared cluster. Same domain (Cilium, zero trust): a policy with mutual authentication, as in the README of the source
  exam ("Cilium L4 mutual TLS").
- Q3: adapted to the real Falco service of `{{NODE01}}`; the validators raise their own harmless `/dev/mem` events.
- Q4: adapted: the webhook backend, the certificates and the configuration files are prepared by the setup; one deliberate mistake
  (wrong port). The backend only denies `untrusted/` repositories, so the other questions are not affected by the plugin.
  This is the only question that uses `--admission-control-config-file`: the Pod Security question (Q9) uses namespace labels.
- Q5: the source only said how to install and run kubesec; the question asks to reach a score and deploy the Pod.
- Q6/Q7: `default` namespace and the GitHub sample manifests replaced by exclusive namespaces and local manifests; the mesh-wide
  policy of Q6 is removed by the session cleanup.
- Q8: the source used `/opt/sbom.spdx`; the file is under `/tmp/exam/mhagou-003-q8/` and the SBOM must really come from the image.
- Q9: the source task only asked for the namespace labels; the seccomp part of its solution is part of the question. The
  source profile allowed only 36 syscalls: nginx cannot run under it (verified: CrashLoopBackOff), so the profile is the
  logging `audit.json` of the Kubernetes documentation.
- Q10: the source asked for a Pod with a projected token; the question states the Secret, the lifetime and the path.
