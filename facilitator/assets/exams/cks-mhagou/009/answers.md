# CKS - MHagou - Exam 9 - Answer key

Commands were run against the lab cluster (kubeadm, `{{CONTROL_PLANE}}`, `{{NODE01}}`, `{{NODE02}}`, containerd).
Namespaces, files and names are the ones used by the questions.

---

## Question 1: Docker daemon of `{{NODE02}}`

The cluster runs containerd; `{{NODE02}}` carries a stand-in for the Docker daemon (`docker.service`) that reads `/etc/docker/daemon.json` like the real one.

```bash
ssh {{NODE02}}
id developer
gpasswd -d developer docker                     # only docker is removed
cat > /etc/docker/daemon.json <<'EOF'
{
  "group": "root",
  "hosts": ["unix:///var/run/docker.sock"]
}
EOF
systemctl daemon-reload
systemctl restart docker
ls -l /var/run/docker.sock                      # srw-rw---- root root
ss -lntp | grep dockerd                         # no output: no TCP listener
exit
kubectl get nodes; kubectl get pods -n kube-system
```

`"group": "root"` sets the group of the socket; `hosts` must list only the Unix socket (no `tcp://`).

## Question 2: projected ServiceAccount token (`monitoring`)

```bash
kubectl -n monitoring patch serviceaccount stats-monitor-sa -p '{"automountServiceAccountToken": false}'
vi /tmp/exam/mhagou-009-q2/deployment.yaml
```

```yaml
    spec:
      serviceAccountName: stats-monitor-sa
      containers:
      - name: stats-monitor-container
        # ...
        volumeMounts:
        - name: token
          mountPath: /var/run/secrets/kubernetes.io/serviceaccount
          readOnly: true
      volumes:
      - name: token
        projected:
          sources:
          - serviceAccountToken:
              path: token
```

```bash
kubectl apply -f /tmp/exam/mhagou-009-q2/deployment.yaml
kubectl -n monitoring rollout status deployment stats-monitor
kubectl -n monitoring exec deploy/stats-monitor -- ls -l /var/run/secrets/kubernetes.io/serviceaccount/
```

Mounting the directory with the projected path `token`, or mounting the single file with `mountPath: .../serviceaccount/token` and `subPath: token`, both give the file the question asks for.

## Question 3: least privilege Roles (`database`)

```bash
kubectl -n database get rolebinding -o wide | grep test-sa        # test-role-1-binding -> Role test-role-1
kubectl -n database edit role test-role-1
```

```yaml
rules:
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["get"]
```

```bash
kubectl -n database create role test-role-2 --verb=update --resource=statefulsets.apps
kubectl -n database create rolebinding test-role-2-binding --role=test-role-2 --serviceaccount=database:test-sa
kubectl auth can-i update statefulsets.apps -n database --as=system:serviceaccount:database:test-sa     # yes
kubectl auth can-i delete secrets -n database --as=system:serviceaccount:database:test-sa               # no
```

## Question 4: Falco incident report (`incident-lab`, `{{NODE01}}`)

```bash
kubectl get pods -n incident-lab -o wide                     # both Pods run on {{NODE01}}
ssh {{NODE01}}
mkdir -p /tmp/exam/mhagou-009-q4
cat > /tmp/exam/mhagou-009-q4/rule.yaml <<'EOF'
- rule: process spawned in a container
  desc: processes of the containers of the node
  condition: evt.type in (execve, execveat) and evt.dir=< and container.id != host
  output: "%evt.time.iso8601,%user.uid,%proc.name"
  priority: NOTICE
EOF
falco -M 42 -r /tmp/exam/mhagou-009-q4/rule.yaml -o json_output=false -o stdout_output.enabled=true 2>/dev/null \
  | sed -nE 's/^[0-9:.]+: [A-Za-z]+ //p' | grep -E '^[0-9]{4}-' | sed -E 's/ container_id=.*$//' > /tmp/exam/mhagou-009-q4/report
cut -d, -f2,3 /tmp/exam/mhagou-009-q4/report | sort | uniq -c
```

`-r` replaces the default rules, so the rule uses raw conditions. `%evt.time.iso8601` is the ISO timestamp. Falco appends the container fields (`container_id=... k8s_pod_name=...`) to every line: the report must have exactly three fields, so cut them (last `sed`). The suspicious process is `nc` (netcat) executed by `api-gateway` as UID 1000; the neighbour `batch-runner` only runs `hostname` as root.

## Question 5: audit logging (`frontend`)

On `{{CONTROL_PLANE}}`, extend the base policy: new rules go **after** the "do not log" rules and the catch-all comes last.

```yaml
apiVersion: audit.k8s.io/v1
kind: Policy
omitStages:
  - "RequestReceived"
rules:
  - level: None
    nonResourceURLs: ["/healthz*", "/readyz*", "/livez*", "/version"]
  - level: None
    users: ["system:kube-proxy"]
    verbs: ["watch"]
    resources:
      - group: ""
        resources: ["endpoints", "services", "services/status"]
  - level: RequestResponse
    resources:
    - group: ""
      resources: ["nodes"]
  - level: Request
    namespaces: ["frontend"]
    resources:
    - group: ""
      resources: ["persistentvolumeclaims"]
  - level: Metadata
    resources:
    - group: ""
      resources: ["configmaps", "secrets"]
  - level: Metadata
```

`/etc/kubernetes/manifests/kube-apiserver.yaml`:

```yaml
    - --audit-policy-file=/etc/kubernetes/logpolicy/audit-policy.yaml
    - --audit-log-path=/var/log/kubernetes/logs.txt
    - --audit-log-maxage=5
    - --audit-log-maxbackup=10
    ...
    volumeMounts:
    - {name: audit-policy, mountPath: /etc/kubernetes/logpolicy, readOnly: true}
    - {name: audit-logs, mountPath: /var/log/kubernetes}
  volumes:
  - name: audit-policy
    hostPath: {path: /etc/kubernetes/logpolicy, type: DirectoryOrCreate}
  - name: audit-logs
    hostPath: {path: /var/log/kubernetes, type: DirectoryOrCreate}
```

Mount the **directories** (a single-file mount of the log cannot be rotated). The first matching rule decides the level. PersistentVolumes are cluster-scoped: a rule limited to a namespace never matches them, which is why this question asks for PersistentVolumeClaims.

## Question 6: ImagePolicyWebhook (`scanner-lab`)

```bash
ssh {{CONTROL_PLANE}}
cd /etc/kubernetes/epconfig
cat admission-config.yaml webhook.kubeconfig
sed -i 's#defaultAllow: true#defaultAllow: false#' admission-config.yaml
sed -i 's#/incomplete#/image_policy#' webhook.kubeconfig
vi /etc/kubernetes/manifests/kube-apiserver.yaml
```

```yaml
    - --enable-admission-plugins=ImagePolicyWebhook          # add to the list if the flag exists (e.g. NodeRestriction,ImagePolicyWebhook)
    - --admission-control-config-file=/etc/kubernetes/epconfig/admission-config.yaml
    ...
    volumeMounts:
    - {name: epconfig, mountPath: /etc/kubernetes/epconfig, readOnly: true}
  volumes:
  - name: epconfig
    hostPath: {path: /etc/kubernetes/epconfig, type: DirectoryOrCreate}
```

Wait for the API server (about a minute), then:

```bash
kubectl run t --image=nginx:1.16 -n scanner-lab --dry-run=server                # rejected: image scanner: vulnerable image
kubectl run t --image=registry.k8s.io/pause:3.10 -n scanner-lab --dry-run=server # accepted
```

If the API server does not start, the logs of its container (`crictl ps -a`, `crictl logs`) show the configuration error. The question 12 also edits `--enable-admission-plugins`: the flag may hold several plugins (`NodeRestriction,ImagePolicyWebhook`).

## Question 7: Falco on one container (`web-tier`, `{{NODE02}}`)

```bash
ssh {{NODE02}}
mkdir -p /tmp/exam/mhagou-009-q7
cat > /tmp/exam/mhagou-009-q7/rule.yaml <<'EOF'
- rule: nginx container processes
  desc: processes executed in the nginx container
  condition: evt.type in (execve, execveat) and evt.dir=< and container.name = "nginx" and k8s.pod.name = "nginx"
  output: "[%evt.time.iso8601],[%user.uid],[%proc.name]"
  priority: NOTICE
EOF
falco -M 25 -r /tmp/exam/mhagou-009-q7/rule.yaml -o json_output=false -o stdout_output.enabled=true 2>/dev/null \
  | sed -nE 's/^[0-9:.]+: [A-Za-z]+ //p' | grep -E '^\[' | sed -E 's/ container_id=.*$//' > /tmp/exam/mhagou-009-q7/falco-incident.txt
cut -d, -f2,3 /tmp/exam/mhagou-009-q7/falco-incident.txt | sort | uniq -c       # [0],[ls] and [0],[sleep]
```

Falco appends the container fields to every line: cut them, the file must contain only the three bracketed fields.

The Pod has two containers: filter on `container.name`, not only on the Pod. Falco needs several seconds to start, so run it a little longer than the time you want to observe.

## Question 8: service on port 389 (`{{NODE01}}`)

```bash
ssh {{NODE01}}
ss -lptn 'sport = :389'                                   # pid=<PID>
mkdir -p /tmp/exam/mhagou-009-q8
lsof -p <PID> | awk '{print $9}' | tail -n +2 > /tmp/exam/mhagou-009-q8/files.txt     # names of the open files
ls -l /proc/<PID>/exe                                      # /usr/local/sbin/ldapd
rm -f /usr/local/sbin/ldapd
```

Note the path of the executable (the `txt` entry of `lsof`, or `/proc/<PID>/exe`) before you stop the process.

## Question 9: user `john` (`john`)

```bash
mkdir -p /tmp/exam/mhagou-009-q9 && cd /tmp/exam/mhagou-009-q9
openssl genrsa -out john.key 2048
openssl req -new -key john.key -subj "/CN=john" -out john.csr
kubectl apply -f - <<EOF
apiVersion: certificates.k8s.io/v1
kind: CertificateSigningRequest
metadata:
  name: john
spec:
  request: $(base64 -w0 < john.csr)
  signerName: kubernetes.io/kube-apiserver-client
  expirationSeconds: 86400
  usages: ["client auth"]
EOF
kubectl certificate approve john
kubectl get csr john -o jsonpath='{.status.certificate}' | base64 -d > john.crt
kubectl -n john create role john-role --verb=list --resource=pods,secrets
kubectl -n john create rolebinding john-role-binding --role=john-role --user=john
kubectl auth can-i list pods -n john --as=john         # yes
kubectl auth can-i list secrets -n john --as=john      # yes
```

## Question 10: deny-all (`testing`)

```bash
kubectl apply -f - <<'EOF'
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: deny-all
  namespace: testing
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress
EOF
```

An empty `podSelector` selects every Pod; listing both policy types without any rule isolates the Pods in both directions (DNS included).

## Question 11: Dockerfile and manifest

```dockerfile
FROM ubuntu:22.04                  # explicit tag (or @sha256 digest), not :latest
RUN apt-get update -y
RUN apt-install nginx -y
COPY entrypoint.sh /
ENTRYPOINT ['/entrypoint.sh']
USER test-user                     # or USER 5487
```

```yaml
      securityContext:
        runAsUser: 5487
        privileged: false
        allowPrivilegeEscalation: false
```

Do not touch anything else (the other lines contain mistakes on purpose; fixing them would count as a change).

## Question 12: API server authentication and authorization

The plain flag `--anonymous-auth=false` makes the kubelet probes of the kube-apiserver Pod (`/livez`, `/readyz` without credentials) fail with 401: the Pod is not Ready and is restarted again and again (verified on this cluster). The structured authentication configuration disables anonymous access except for the chosen paths:

```bash
ssh {{CONTROL_PLANE}}
mkdir -p /etc/kubernetes/authn
cat > /etc/kubernetes/authn/authentication-config.yaml <<'EOF'
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
    - --authentication-config=/etc/kubernetes/authn/authentication-config.yaml
    - --authorization-mode=Node,RBAC
    - --enable-admission-plugins=NodeRestriction        # the flag is absent at the start of the exercise
    ...
    volumeMounts:
    - {name: authn, mountPath: /etc/kubernetes/authn, readOnly: true}
  volumes:
  - name: authn
    hostPath: {path: /etc/kubernetes/authn, type: DirectoryOrCreate}
```

The `--anonymous-auth` flag cannot be combined with `--authentication-config`. After the restart:

```bash
kubectl delete clusterrolebinding system:anonymous
kubectl get nodes
curl -k https://<api-server>:6443/api              # 401 for anonymous requests
curl -k https://<api-server>:6443/readyz           # ok (the kubelet probe)
```

The authorization mode is already `Node,RBAC` (it is required for `NodeRestriction` to be effective): keep it. Question 6 edits the same flag `--enable-admission-plugins`: use a comma separated list.

## Question 13: ValidatingAdmissionPolicy (`registry-gate`)

```bash
kubectl apply -f - <<'EOF'
apiVersion: admissionregistration.k8s.io/v1
kind: ValidatingAdmissionPolicy
metadata:
  name: deny-latest-tag
spec:
  failurePolicy: Fail
  matchConstraints:
    resourceRules:
    - apiGroups: [""]
      apiVersions: ["v1"]
      operations: ["CREATE", "UPDATE"]
      resources: ["pods"]
  validations:
  - expression: "object.spec.containers.all(c, c.image.contains('@') || (c.image.split('/')[size(c.image.split('/')) - 1].contains(':') && !c.image.endsWith(':latest')))"
    message: "images must be pinned (no latest tag, no untagged image)"
---
apiVersion: admissionregistration.k8s.io/v1
kind: ValidatingAdmissionPolicyBinding
metadata:
  name: deny-latest-tag-binding
spec:
  policyName: deny-latest-tag
  validationActions: ["Deny"]
  matchResources:
    namespaceSelector:
      matchLabels:
        kubernetes.io/metadata.name: registry-gate
EOF
kubectl run t --image=nginx:latest -n registry-gate --dry-run=server        # denied
kubectl run t --image=nginx:1.27 -n registry-gate --dry-run=server          # accepted
```

---

## Notes on this exam

- It is built from `mhagou/exam-9`. Q1 uses a stand-in for the Docker daemon (the cluster runs containerd); Q4, Q7 and Q8 are on worker nodes; Q4/Q7 use Falco (Sysdig is not installed).
- Question 13 replaces the second ImagePolicyWebhook task of the source: the API server accepts a single admission configuration file, owned by question 6.
- Question 5 asks for PersistentVolumeClaims (the source said PersistentVolumes, which are cluster-scoped).
- Questions 5, 6 and 12 edit `kube-apiserver.yaml` (different flags; 6 and 12 share `--enable-admission-plugins`).
