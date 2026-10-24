# CKS - MHagou - Exam 1 - Answer key

Commands were run against the lab cluster (kubeadm, `{{CONTROL_PLANE}}`, `{{NODE01}}`, `{{NODE02}}`). The questions come from the
source lab "exam-1"; the decisions (what was kept, adapted or replaced) are in the exam documentation of the repository.

---

## Question 1: ImagePolicyWebhook and NodeRestriction

```bash
ssh {{CONTROL_PLANE}}
# the file already exists (written by the setup); this is its content:
cat > /etc/kubernetes/admission/admission-config.yaml <<'EOF'
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
EOF
vi /etc/kubernetes/manifests/kube-apiserver.yaml
```

```yaml
    - --enable-admission-plugins=NodeRestriction,ImagePolicyWebhook      # keep the plugins that are already there
    - --admission-control-config-file=/etc/kubernetes/admission/admission-config.yaml
    ...
    volumeMounts:
    - {name: admission, mountPath: /etc/kubernetes/admission, readOnly: true}
  volumes:
  - name: admission
    hostPath: {path: /etc/kubernetes/admission, type: DirectoryOrCreate}
```

The kubelet recreates the API server (about a minute). Check:

```bash
kubectl run t --image=nginx:latest -n webhook-lab --dry-run=server     # denied by the image policy webhook
kubectl run t --image=nginx:1.27 -n webhook-lab --dry-run=server       # accepted
```

Pitfalls: `defaultAllow: false` makes the plugin fail closed (a wrong webhook address blocks every Pod); the directory must be
mounted, otherwise the API server cannot read the file and does not start (`crictl logs` of the kube-apiserver container
shows it). Only this question changes the admission configuration of the API server.

## Question 2: AppArmor + seccomp + Pod Security Standards

```bash
ssh {{NODE01}} 'apparmor_parser -r /etc/apparmor.d/secure-profile && grep secure-profile /sys/kernel/security/apparmor/profiles'
kubectl label namespace secured-area pod-security.kubernetes.io/enforce=restricted
```

`/tmp/exam/mhagou-001-q2/secure-pod.yaml`:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: secure-nginx
  namespace: secured-area
spec:
  nodeName: {{NODE01}}
  securityContext:
    runAsNonRoot: true
    seccompProfile: {type: RuntimeDefault}
    appArmorProfile: {type: Localhost, localhostProfile: secure-profile}
  containers:
  - name: nginx
    image: nginxinc/nginx-unprivileged:1.27-alpine
    command: ["nginx", "-g", "daemon off;"]
    securityContext:
      allowPrivilegeEscalation: false
      capabilities: {drop: ["ALL"]}
```

```bash
kubectl apply -f /tmp/exam/mhagou-001-q2/secure-pod.yaml
kubectl exec -n secured-area secure-nginx -- cat /proc/1/attr/current     # secure-profile (enforce)
```

The restricted standard also requires `runAsNonRoot`, `allowPrivilegeEscalation: false` and `capabilities.drop: [ALL]`: the
error message of the admission lists what is missing. The profile denies the execution of `/bin/sh` and of `/bin/busybox`
(AppArmor matches the resolved path: in this image `/bin/sh` is a link to busybox), so the Pod starts nginx directly (the
entrypoint script of the image needs a shell). The profile is effective for the programs that the container starts:
`kubectl exec -n secured-area secure-nginx -- /bin/sh -c ls` ends with "Permission denied" (the first process of an exec is
started before the profile applies).

## Question 3: kube-bench, checksums and a malicious container

1. kube-bench on `{{NODE02}}`:

```bash
ssh {{NODE02}}
kube-bench run --targets node --check 4.2.1
yq -i '.authentication.anonymous.enabled = false' /var/lib/kubelet/config.yaml   # or edit the file by hand
systemctl restart kubelet
kube-bench run --targets node --check 4.2.1                                       # PASS
```

2. Checksums:

```bash
cd /tmp/exam/mhagou-001-q3/manifests
sha512sum -c ../SHA512SUMS | grep -v ': OK'              # the manifest that FAILED
echo kube-scheduler.yaml > /tmp/exam/mhagou-001-q3/modified.txt     # the name of the failed one
```

3. The container on `{{NODE01}}`:

```bash
ssh {{NODE01}}
ps -eo pid,args | grep cryptominer
crictl ps -a | grep runner                 # or: crictl ps -a --label io.kubernetes.pod.name=batch-runner
crictl stop <container-id> && crictl rm <container-id>
```

Only the miner container is removed; deleting the Pod `batch-runner` with kubectl removes the container too.

## Question 4: Cilium egress deny

```bash
kubectl apply -f - <<'EOF'
apiVersion: cilium.io/v2
kind: CiliumNetworkPolicy
metadata:
  name: p1
  namespace: team-azure
spec:
  endpointSelector:
    matchLabels:
      role: messenger
  egressDeny:
  - toEndpoints:
    - matchLabels:
        role: database
EOF
```

`egressDeny` only blocks the listed destination: DNS and the traffic to `cache` are untouched because the policy
`baseline-allow` of the namespace allows everything else (with Cilium an endpoint selected by any egress rule, deny rules
included, is in default deny for the egress unless an allow rule exists: do not delete `baseline-allow`). A deny rule always
wins over an allow rule.

## Question 5: Dockerfile and Deployment

`/tmp/exam/mhagou-001-q5/Dockerfile`:

```dockerfile
FROM ubuntu:22.04
RUN apt-get update && apt-get install -y curl && useradd -u 10001 app
COPY app.tar.gz /opt/app/
USER app
CMD ["/opt/app/run.sh"]
```

`/tmp/exam/mhagou-001-q5/deployment.yaml`, container `securityContext`:

```yaml
        securityContext:
          privileged: false
          capabilities:
            drop: ["ALL"]
```

`COPY` does not unpack the archive (`ADD` did): the content of `app.tar.gz` is extracted by a `RUN tar -xzf` step if it is needed.

## Question 6: encryption of Secrets at rest

```bash
ssh {{CONTROL_PLANE}}
head -c 32 /dev/urandom | base64
# the file already exists with a placeholder for the key (edit it, or write it like this):
cat > /etc/kubernetes/etcd-encryption.yaml <<'EOF'
apiVersion: apiserver.config.k8s.io/v1
kind: EncryptionConfiguration
resources:
  - resources:
      - secrets
    providers:
      - aescbc:
          keys:
            - name: key1
              secret: <the base64 string>
      - identity: {}
EOF
vi /etc/kubernetes/manifests/kube-apiserver.yaml
```

```yaml
    - --encryption-provider-config=/etc/kubernetes/etcd-encryption.yaml
    ...
    volumeMounts:
    - {name: enc, mountPath: /etc/kubernetes/etcd-encryption.yaml, readOnly: true}
  volumes:
  - name: enc
    hostPath: {path: /etc/kubernetes/etcd-encryption.yaml, type: File}
```

After the API server is back:

```bash
kubectl create secret generic probe --from-literal=k=v
ETCD=$(crictl ps --name etcd -q)
crictl exec $ETCD etcdctl --endpoints=https://127.0.0.1:2379 --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt --key=/etc/kubernetes/pki/etcd/server.key get /registry/secrets/default/probe | hexdump -C | head
```

The value starts with `k8s:enc:aescbc:v1:key1`. The first provider is the one used to write: with `identity` first the new
Secrets stay in plain text. Secrets created before the change stay unencrypted until they are rewritten
(`kubectl get secrets -A -o json | kubectl replace -f -`).

## Question 7: Falco rule for /etc/shadow

```bash
ssh {{NODE01}}
cat >> /etc/falco/falco_rules.local.yaml <<'EOF'
- rule: Shadow file read
  desc: a process reads /etc/shadow
  condition: open_read and fd.name = /etc/shadow
  output: "SHADOW READ: file=%fd.name process=%proc.name user=%user.name"
  priority: WARNING
EOF
falco -V /etc/falco/falco_rules.local.yaml
systemctl restart falco-modern-bpf
journalctl -u falco-modern-bpf -f | grep 'SHADOW READ'
```

In another terminal: `kubectl exec -n shadow-watch report-agent -- cat /etc/shadow`.

Pitfalls: an `output:` with a colon must be quoted (otherwise the YAML is invalid and Falco does not start); `open_read` is
a macro of the default rules (they are loaded by the service). Falco's default rule "Read sensitive file untrusted"
reports the same read; in this lab Falco evaluates all matching rules (`rule_matching: all` is set for this exam), with
the default `first` an earlier rule would hide a new rule.

## Question 8: least privilege RBAC

```bash
kubectl apply -f - <<'EOF'
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: release-role
  namespace: release-lab
rules:
- apiGroups: [""]
  resources: ["pods", "pods/log"]
  verbs: ["get", "list", "watch"]
- apiGroups: ["apps"]
  resources: ["deployments"]
  verbs: ["get", "list", "watch", "update", "patch"]
EOF
kubectl auth can-i delete pods --as=system:serviceaccount:release-lab:release-bot -n release-lab      # no
```

Check with `kubectl auth can-i --list --as=system:serviceaccount:release-lab:release-bot -n release-lab`. Do not delete the
RoleBinding and do not touch `audit-bot`.

## Question 9: NetworkPolicy for redis-backend

```bash
kubectl get pod -n prod-x12cs --show-labels; kubectl get ns --show-labels
kubectl apply -f - <<'EOF'
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-redis-access
  namespace: prod-x12cs
spec:
  podSelector:
    matchLabels:
      run: redis-backend
  policyTypes:
  - Ingress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          access: redis
    - podSelector:
        matchLabels:
          backend: prod-x12cs
    ports:
    - protocol: TCP
      port: 6379
EOF
```

The two `from` entries are separate items (OR): the namespace `prod-yx13cs` (label `access=redis`) as a whole, or the
labelled Pods of the policy's own namespace. The `ports` list limits both to TCP 6379.

## Question 10: projected ServiceAccount token

```bash
kubectl patch serviceaccount vault-sa -n vault-lab -p '{"automountServiceAccountToken": false}'
kubectl delete pod immutable-pod -n vault-lab --now
```

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: immutable-pod
  namespace: vault-lab
spec:
  serviceAccountName: vault-sa
  securityContext:
    runAsNonRoot: true
    runAsUser: 10001
  containers:
  - name: app
    image: busybox:1.36
    command: ["sleep", "3600"]
    securityContext:
      readOnlyRootFilesystem: true
    volumeMounts:
    - {name: sa-token, mountPath: /var/run/secrets/kubernetes.io/serviceaccount, readOnly: true}
    - {name: tmp, mountPath: /tmp}
  volumes:
  - name: sa-token
    projected:
      sources:
      - serviceAccountToken: {path: token, expirationSeconds: 3600}
  - name: tmp
    emptyDir: {}
```

`runAsNonRoot: true` needs a numeric `runAsUser` for an image that runs as root (busybox). With `automountServiceAccountToken`
still enabled, the Pod would have two volumes mounted at the same path and would not be created.
