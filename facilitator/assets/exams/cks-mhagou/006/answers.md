# CKS - MHagou - Exam 6 - Answer key
Converted from the labs of `mhagou/exam-6`; commands were run against the lab cluster (kubeadm, three nodes: `{{CONTROL_PLANE}}`, `{{NODE01}}`, `{{NODE02}}`). Namespaces, node names and file locations are the ones used by the questions.

---

## Question 1: audit policy and log (control plane)

```bash
ssh {{CONTROL_PLANE}}
mkdir -p /etc/kubernetes/audit
cat > /etc/kubernetes/audit/policy.yaml <<'EOF'
apiVersion: audit.k8s.io/v1
kind: Policy
rules:
- level: Metadata
  resources:
  - group: ""
    resources: ["pods", "services", "configmaps", "secrets"]
- level: Request
  verbs: ["create", "update", "patch", "delete"]
EOF
vi /etc/kubernetes/manifests/kube-apiserver.yaml
```

```yaml
    - --audit-policy-file=/etc/kubernetes/audit/policy.yaml
    - --audit-log-path=/etc/kubernetes/audit/logs/audit.log
    - --audit-log-maxsize=500
    - --audit-log-maxbackup=5
    - --audit-log-maxage=7
    ...
    volumeMounts:
    - {name: audit, mountPath: /etc/kubernetes/audit}
  volumes:
  - name: audit
    hostPath: {path: /etc/kubernetes/audit, type: DirectoryOrCreate}
```

Mount the DIRECTORY (the policy is read from it and the log is written below it): a single-file mount of the log breaks the rotation. Wait for the API server (about a minute), then check `tail -n 3 /etc/kubernetes/audit/logs/audit.log`.

Rules are evaluated in order and the first match wins: the Metadata rule for the four resources must come before the Request rule for the mutating verbs (a pod creation matches both).

---

## Question 2: Falco rule for `/tmp/mem` (`mem-watch`)

```bash
ssh {{NODE01}}
cat >> /etc/falco/falco_rules.local.yaml <<'EOF'
- rule: Read of /tmp/mem
  desc: A process reads /tmp/mem
  condition: evt.type in (open, openat, openat2) and evt.dir = < and fd.name = /tmp/mem and container.id != host
  output: "Process %proc.name read /tmp/mem (cmd=%proc.cmdline user=%user.name pod=%k8s.pod.name ns=%k8s.ns.name container=%container.id image=%container.image.repository)"
  priority: WARNING
EOF
systemctl restart falco-modern-bpf
journalctl -u falco-modern-bpf -f          # in another terminal: kubectl exec -n mem-watch deploy/compute-c -- cat /tmp/mem
```

`spawned_process`/`container` macros exist in the default rules, so they can be used here (the service loads them). Falco evaluates rules with `rule_matching: first`: if an earlier default rule also matches the same event it reports it first (not the case for a plain read of this file). Use `%k8s.pod.name` / `%container.id` in the output to identify the workload (the container plugin of the Falco service also appends `container_id=... k8s_pod_name=...` to the output of every rule on its own: relying on it is accepted by the check, writing the fields explicitly is the better practice).

---

## Question 3: TLS Ingress with a backend in another namespace (`asia`, `europe`, `world`)

```bash
kubectl create deployment web -n asia --image=nginx --port=80 --replicas=2
kubectl expose deployment web -n asia --port=80
kubectl create deployment web -n europe --image=nginx --port=80 --replicas=2
kubectl expose deployment web -n europe --port=80
kubectl create secret tls test-secret -n world --cert=/tmp/exam/mhagou-006-q3/cert.crt --key=/tmp/exam/mhagou-006-q3/cert.key
```

An Ingress can only use Services of its own namespace, so `world` needs a Service `europe`. `type: ExternalName` (`europe.europe.svc.cluster.local`) is the classic answer for ingress-nginx, but Traefik of this cluster does not follow ExternalName Services (`allowExternalNameServices` is off). A Service without selector with an EndpointSlice that lists the backend Pod IPs (or the ClusterIP of the Service of `europe`) works:

```yaml
apiVersion: v1
kind: Service
metadata: {name: europe, namespace: world}
spec:
  ports: [{port: 80, targetPort: 80}]
---
apiVersion: discovery.k8s.io/v1
kind: EndpointSlice
metadata:
  name: europe-1
  namespace: world
  labels: {kubernetes.io/service-name: europe}
addressType: IPv4
ports: [{name: "", port: 80, protocol: TCP}]
endpoints:
- addresses: ["<IP of the Service europe/web (kubectl get svc -n europe)>"]
  conditions: {ready: true}
```

Strip the prefix with a Traefik middleware and reference it from the Ingress:

```yaml
apiVersion: traefik.io/v1alpha1
kind: Middleware
metadata: {name: strip-europe, namespace: world}
spec:
  stripPrefix: {prefixes: ["/europe"]}
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: world
  namespace: world
  annotations:
    traefik.ingress.kubernetes.io/router.middlewares: world-strip-europe@kubernetescrd
spec:
  ingressClassName: traefik
  tls:
  - hosts: [world.universe.mine]
    secretName: test-secret
  rules:
  - host: world.universe.mine
    http:
      paths:
      - {path: /europe, pathType: Prefix, backend: {service: {name: europe, port: {number: 80}}}}
```

Check: `curl --cacert /tmp/exam/mhagou-006-q3/cert.crt --resolve world.universe.mine:443:<traefik ip> https://world.universe.mine/europe` (`kubectl get svc -n traefik`). A wrong annotation shows in `kubectl logs -n traefik deploy/traefik`, not in `kubectl describe ingress`.

---

## Question 4: Dockerfile and Deployment (files)

Dockerfile: `FROM ubuntu:22.04`. Steps that need root (here `RUN apt-get install`) must keep running as root, so a `USER root` before them stays and is changed in the place that decides the runtime user: `USER nobody` right before `CMD` (the last `USER` of the final stage). Changing the first `USER root` to `nobody` would break the package installation.

Deployment.yaml: `apiVersion: apps/v1`, and for the container `kafka` AND the init container `prepare`: `privileged: false` and `readOnlyRootFilesystem: true`. Other settings stay as they are.

Check: `kubectl create --dry-run=client -f /tmp/exam/mhagou-006-q4/Deployment.yaml` and `grep -n USER /tmp/exam/mhagou-006-q4/Dockerfile`.

---

## Question 5: Falco capture of one nginx container (`nginx-watch`)

```bash
ssh {{NODE02}}
mkdir -p /tmp/exam/mhagou-006-q5
cat > /tmp/exam/mhagou-006-q5/rule.yaml <<'EOF'
- rule: web-1 processes
  desc: processes started in the selected nginx container
  condition: evt.type in (execve, execveat) and evt.dir = < and k8s.pod.name = web-1
  output: "[%evt.time],[%user.uid],[%proc.name]"
  priority: WARNING
EOF
timeout 40 falco -r /tmp/exam/mhagou-006-q5/rule.yaml 2>/dev/null \
  | grep -oE '\[[^]]*\],\[[0-9]+\],\[[^]]*\]' > /tmp/exam/mhagou-006-q5/incident.txt
```

`-r` replaces the default rules (no default macros). A container id works too: `container.id = <12 characters>`. Falco takes several seconds to start, so run it for 30-40 seconds. The service of the node keeps running; a second instance started by hand is fine. Falco prints `<time>: <priority> <output>` and, with the default `append_output: suggested_output: true` of `falco.yaml`, the container fields (`container_id=...`) after the output: the validator accepts that, so the plain stdout of Falco is a valid file. `grep -o` (as above) writes nothing but the three bracketed fields, and `-o 'append_output[0].suggested_output=false'` removes the appended fields.

---

## Question 6: process on port 389 (`{{NODE01}}`)

```bash
ssh {{NODE01}}
ss -ltnp 'sport = :389'                       # or: lsof -nP -iTCP:389 -sTCP:LISTEN
PID=<pid>
lsof -p $PID > /tmp/exam/mhagou-006-q6/files.txt       # open files and the listening socket
ls -l /proc/$PID/exe                                  # the executable: /usr/local/sbin/ldapd
rm /usr/local/sbin/ldapd
```

Get the path of the executable before anything else happens to the process (it also appears as the `txt` line of `lsof -p`). The process keeps running after the executable is removed.

---

## Question 7: RuntimeClass `not-trusted` (`sandbox-lab`)

```bash
kubectl apply -f - <<'EOF'
apiVersion: node.k8s.io/v1
kind: RuntimeClass
metadata:
  name: not-trusted
handler: runsc
EOF
kubectl -n sandbox-lab patch deployment report-api --type merge -p '{"spec":{"template":{"spec":{"runtimeClassName":"not-trusted"}}}}'
kubectl -n sandbox-lab rollout status deployment report-api
kubectl -n sandbox-lab exec deploy/report-api -- dmesg | head -3        # gVisor
```

---

## Question 8: secure the kubelet (control plane)

```bash
ssh {{CONTROL_PLANE}}
curl -sk https://localhost:10250/pods | head -c 100       # answers: anonymous access is open
curl -sk http://localhost:10255/pods | head -c 100        # the read-only port answers too
vi /var/lib/kubelet/config.yaml
```

```yaml
authentication:
  anonymous:
    enabled: false
  webhook:
    enabled: true
authorization:
  mode: Webhook
readOnlyPort: 0
```

```bash
systemctl restart kubelet
systemctl is-active kubelet
curl -sk https://localhost:10250/pods                     # Unauthorized (401)
ss -ltn | grep 10255                                      # nothing
```

Do not leave `--anonymous-auth` / `--authorization-mode` flags in `/var/lib/kubelet/kubeadm-flags.env` that override the file. The check reads the RUNNING configuration (`kubectl get --raw /api/v1/nodes/{{CONTROL_PLANE}}/proxy/configz`).

---

## Question 9: client certificate for `60099@internal.users`

```bash
cd /tmp && openssl genrsa -out 60099.key 2048
openssl req -new -key 60099.key -out 60099.csr -subj "/CN=60099@internal.users"
cat <<EOF | kubectl apply -f -
apiVersion: certificates.k8s.io/v1
kind: CertificateSigningRequest
metadata:
  name: user-60099
spec:
  request: $(base64 -w0 60099.csr)
  signerName: kubernetes.io/kube-apiserver-client
  expirationSeconds: 86400
  usages: [client auth]
EOF
kubectl certificate approve user-60099
kubectl get csr user-60099 -o jsonpath='{.status.certificate}' | base64 -d > 60099.crt
kubectl config set-credentials 60099@internal.users --client-key=60099.key --client-certificate=60099.crt --embed-certs=true
kubectl config set-context 60099@internal.users --cluster=$(kubectl config view -o jsonpath='{.clusters[0].name}') --user=60099@internal.users
kubectl --context 60099@internal.users auth whoami
kubectl --context 60099@internal.users get pods -n staff-lab        # Error from server (Forbidden)
```

Do not create a Role or RoleBinding for this user.

---

## Question 10: AppArmor and seccomp (`kernel-lab`, `{{NODE01}}`)

```bash
ssh {{NODE01}}
vi /tmp/exam/mhagou-006-q10/apparmor-profile          # add:  deny /** w,
apparmor_parser -r /tmp/exam/mhagou-006-q10/apparmor-profile
aa-status | grep k8s-apparmor-example-deny-write
cat > /var/lib/kubelet/seccomp/profiles/audit.json <<'EOF'
{"defaultAction": "SCMP_ACT_ALLOW",
 "syscalls": [{"names": ["mount"], "action": "SCMP_ACT_ERRNO"}]}
EOF
exit
```

`hello-apparmor.yaml`, in `spec`:

```yaml
  securityContext:
    appArmorProfile:
      type: Localhost
      localhostProfile: k8s-apparmor-example-deny-write
```

`audit-pod.yaml`: replace the seccomp profile and add the container security context:

```yaml
  securityContext:
    seccompProfile:
      type: Localhost
      localhostProfile: profiles/audit.json
  containers:
  - name: test-container
    ...
    securityContext:
      allowPrivilegeEscalation: false
```

```bash
kubectl apply -f /tmp/exam/mhagou-006-q10/hello-apparmor.yaml -f /tmp/exam/mhagou-006-q10/audit-pod.yaml
kubectl -n kernel-lab exec hello-apparmor -- mkdir /test            # Permission denied
```

The profile keeps the `signal (receive)` rules of the starter, otherwise the runtime cannot stop the container. `localhostProfile` of seccomp is relative to `/var/lib/kubelet/seccomp`.

---

## Question 11: restricted Pod Security (`pss-test`)

```bash
kubectl label namespace pss-test pod-security.kubernetes.io/enforce=restricted
kubectl run test-pod -n pss-test --image=nginx --dry-run=server        # rejected: the message lists what is missing
```

The error lists the violations: `allowPrivilegeEscalation`, `capabilities.drop: ["ALL"]`, `runAsNonRoot`, `seccompProfile`. A compliant Pod (the stock nginx image runs as root and writes to `/var/cache/nginx` and `/run`, so use a non-root UID and writable volumes):

```yaml
apiVersion: v1
kind: Pod
metadata: {name: test-pod, namespace: pss-test}
spec:
  securityContext:
    runAsUser: 101
    runAsNonRoot: true
    seccompProfile: {type: RuntimeDefault}
  containers:
  - name: nginx
    image: nginx
    securityContext:
      allowPrivilegeEscalation: false
      capabilities: {drop: ["ALL"]}
    volumeMounts:
    - {name: run, mountPath: /run}
    - {name: cache, mountPath: /var/cache/nginx}
  volumes:
  - {name: run, emptyDir: {}}
  - {name: cache, emptyDir: {}}
```

(`nginxinc/nginx-unprivileged` is an alternative image.) Check `kubectl -n pss-test exec test-pod -- id -u`.

---

## Question 12: TLS of the control plane

```bash
ssh {{CONTROL_PLANE}}
vi /etc/kubernetes/manifests/kube-apiserver.yaml
```

```yaml
    - --tls-min-version=VersionTLS13
    - --tls-cipher-suites=TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256
```

```bash
vi /etc/kubernetes/manifests/etcd.yaml
```

```yaml
    - --cipher-suites=TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256
    - --listen-client-urls=https://127.0.0.1:2379,https://192.168.99.200:2379     # remove http://127.0.0.1:2399
```

The kubelet restarts both static Pods (about a minute). Check: `crictl ps`, `ss -ltn | grep -E '2379|2399'`, `openssl s_client -connect 192.168.99.200:6443 -tls1_2 </dev/null` (fails), `-tls1_3` (works), `kubectl get --raw '/readyz?verbose' | grep etcd`.

The cipher suite flags only affect TLS 1.2 (the TLS 1.3 suites are fixed by Go): with `--tls-min-version=VersionTLS13` the list is accepted but not used by the handshake. A manifest typo makes the static Pod crash-loop: use `crictl logs` to see the reason.

---

## Question 13: Cilium egress policy (`app`, `data`, `manage`)

```bash
kubectl apply -f - <<'EOF'
apiVersion: cilium.io/v2
kind: CiliumNetworkPolicy
metadata:
  name: policy1
  namespace: app
spec:
  endpointSelector: {}
  egress:
  - toEndpoints:
    - matchLabels:
        io.kubernetes.pod.namespace: data
        id: data
EOF
IP=$(kubectl get pod -n manage manage1 -o jsonpath='{.status.podIP}')
kubectl exec -n app app1 -- wget -q -T 4 -O- http://$IP        # times out
```

`toEndpoints` (not `toEndPoints`) takes label selectors; the namespace is selected with the label `io.kubernetes.pod.namespace`. An egress rule makes the policy default-deny for egress, DNS included (the check uses Pod IPs).

---

## Question 14: inspect a container from the node (`inspect-lab`)

```bash
kubectl -n inspect-lab get pod test -o wide                  # {{NODE01}}
ssh {{NODE01}}
CID=$(crictl ps --name main -q)
PID=$(crictl inspect $CID | jq .info.pid)
crictl inspect $CID | jq -r '.status.image.image, .status.imageRef'     # image repository (strip the tag)
timeout 12 strace -f -e trace=execve -p $PID 2>&1 | grep execve        # execve("/bin/<process>", ...)
ps -o uid,comm --ppid $PID                                              # or: grep Uid /proc/<pid of the child>/status
cat > /tmp/exam/mhagou-006-q14/report.txt <<'EOF'
process=<name>
uid=<uid>
image=docker.io/library/busybox
EOF
```

`kubectl get pod test -o yaml` also shows the uid (`runAsUser`) and the image: the report is the result of inspecting the real container (`strace` shows what is executed, `/proc/<pid>/status` the uid of the process).

---

## Question 15: SBOMs (files)

```bash
cd /tmp/exam/mhagou-006-q15
trivy image --format spdx-json --output sbom1.json alpine:3.20.3
trivy image --format cyclonedx --output sbom2.json busybox:1.36.1
trivy sbom --severity HIGH,CRITICAL --format json --output sbom_result.json sbom_check.json
```

The source lab also used `bom`, `syft` and `grype`; only `trivy` is installed on the jumphost of this lab (`bom generate spdx-json --image <image>` and `syft <image> -o spdx-json` are the equivalents for the SPDX generation).

---

## Question 16: RuntimeClass and a Pod in the gVisor sandbox (`gvisor-lab`)

```bash
kubectl apply -f - <<'YAML'
apiVersion: node.k8s.io/v1
kind: RuntimeClass
metadata:
  name: hardened
handler: runsc
YAML
kubectl run secure -n gvisor-lab --image=nginx --dry-run=client -o yaml > /tmp/secure.yaml
# add under spec: runtimeClassName: hardened   and   nodeName: {{NODE02}} (or a nodeSelector)
kubectl apply -f /tmp/secure.yaml
kubectl -n gvisor-lab exec secure -- dmesg | head -3           # "Starting gVisor..."
```

The field is `runtimeClassName`; the handler `runsc` must be configured in the containerd of the node (it is on `{{NODE02}}`).

---

## Question 17: docker group and the TCP listener (`{{NODE02}}`)

```bash
ssh {{NODE02}}
gpasswd -d developer docker                 # id developer: no docker group any more
systemctl cat lab-docker                    # ExecStart=... -H unix:///var/run/lab-docker.sock -H tcp://0.0.0.0:2375
systemctl edit --full lab-docker            # or vi /etc/systemd/system/lab-docker.service: delete  -H tcp://0.0.0.0:2375
systemctl daemon-reload
systemctl restart lab-docker
ss -ltn | grep 2375                         # nothing
```

On a real Docker host the same applies to `docker.service` (`ExecStart=/usr/bin/dockerd -H fd:// -H tcp://...`): membership of the `docker` group is root-equivalent access, and a TCP socket without TLS is remote root. Docker is not installed on the nodes of this lab: the daemon is a stand-in started by the unit `lab-docker`.

---
