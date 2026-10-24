# CKS-002 Practice Lab – Answers

## Question 1: Default-Deny NetworkPolicy for a Namespace

Create a NetworkPolicy named `deny-all` in the `testing` namespace that denies **all ingress and egress** for **all pods** in the namespace.

```yaml
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
  ingress: []
  egress: []
```

This policy:
- Selects **all pods** in `testing` via `podSelector: {}`.
- Sets `policyTypes` to both `Ingress` and `Egress`.
- Uses **empty** `ingress` and `egress` lists, which means no traffic is allowed.

Verification (as in validation scripts):
- Check that the policy exists:
  - `kubectl get networkpolicy deny-all -n testing`
- Confirm it has `Ingress` and `Egress` in `.spec.policyTypes` and empty `ingress`/`egress` arrays.

---

## Question 2: A dedicated ServiceAccount with a manually mounted token

1. Create the ServiceAccount with automatic token mounting disabled:

   ```bash
   kubectl create serviceaccount app-sa -n legacy-tokens
   kubectl patch serviceaccount app-sa -n legacy-tokens -p '{"automountServiceAccountToken": false}'
   ```

2. Create a long-lived token Secret for it (the token controller fills in the token):

   ```yaml
   apiVersion: v1
   kind: Secret
   metadata:
     name: app-sa-token
     namespace: legacy-tokens
     annotations:
       kubernetes.io/service-account.name: app-sa
   type: kubernetes.io/service-account-token
   ```

3. A Pod's ServiceAccount cannot be changed in place: recreate `web` using `app-sa` and mount the Secret so that the token is the file `/var/run/secrets/kubernetes.io/serviceaccount/token`:

   ```yaml
   apiVersion: v1
   kind: Pod
   metadata:
     name: web
     namespace: legacy-tokens
   spec:
     serviceAccountName: app-sa
     containers:
     - name: nginx
       image: nginx
       volumeMounts:
       - name: token
         mountPath: /var/run/secrets/kubernetes.io/serviceaccount/token
         subPath: token
         readOnly: true
     volumes:
     - name: token
       secret:
         secretName: app-sa-token
   ```

   Mounting the Secret at the directory `/var/run/secrets/kubernetes.io/serviceaccount` (without `subPath`) is equally valid.

4. Verify:

   ```bash
   kubectl exec web -n legacy-tokens -- cat /var/run/secrets/kubernetes.io/serviceaccount/token
   ```

---

## Question 3: Harden Dockerfile and Pod Manifest

Fix **two issues** in the Dockerfile and **two issues** in the Pod manifest without adding/removing fields. Use non‑root user `test-user` with UID `5375`.

### Original (insecure) Dockerfile

```dockerfile
FROM ubuntu:latest
RUN apt-get update -y
RUN apt-get install nginx -y
COPY entrypoint.sh /
ENTRYPOINT ["/entrypoint.sh"]
USER ROOT
```

### Hardened Dockerfile

```dockerfile
FROM ubuntu:20.04
RUN apt-get update -y
RUN apt-get install nginx -y
COPY entrypoint.sh /
ENTRYPOINT ["/entrypoint.sh"]
USER test-user
```

Changes:
- Pin base image to a **fixed version** (e.g. `ubuntu:20.04`) or to a digest instead of `latest`.
- Run as non‑root user `test-user` (UID 5375) instead of `ROOT` (`USER 5375` is accepted too).

### Original (insecure) Pod manifest

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: security-context-demo-2
spec:
  securityContext:
    runAsUser: 1000
  containers:
  - name: security-context-demo-2
    image: gcr.io/google-samples/node-hello:1.0
    securityContext:
      runAsUser: 0
      privileged: true
      allowPrivilegeEscalation: false
```

### Hardened Pod manifest

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: security-context-demo-2
spec:
  securityContext:
    runAsUser: 1000
  containers:
  - name: security-context-demo-2
    image: gcr.io/google-samples/node-hello:1.0
    securityContext:
      runAsUser: 5375
      privileged: false
      allowPrivilegeEscalation: false
```

Changes:
- Container `runAsUser` set to **5375** (non‑root `test-user`).
- `privileged` set to **false**.

These satisfy the requirement to harden both image and pod without changing the schema.

---

## Question 4: Ensure Stateless, Immutable Pods in `prod`

Goal: in `prod`, delete every Pod that is **stateful** (a volume that holds data: `emptyDir`, `hostPath`, PVC) or **not immutable** (a privileged container, or a root filesystem that is not read-only). Pods that are compliant must be kept.

1. Show the volumes and security settings of all Pods at once:

   ```bash
   kubectl get pods -n prod -o json | jq -r '.items[] | .metadata.name as $n
     | "\($n) volumes=\([.spec.volumes[]? | keys[] | select(. != "name")] | join(",")) containers=\([.spec.containers[] | "\(.name):priv=\(.securityContext.privileged // false),ro=\(.securityContext.readOnlyRootFilesystem // false)"] | join(" "))"'
   ```

2. Pods to delete:

   | Pod | Why |
   |---|---|
   | `report-worker` | `emptyDir` volume (stateful), even though its root filesystem is read-only |
   | `batch-runner` | privileged container |
   | `payments-api` | the `log-shipper` sidecar has a writable root filesystem |

   Pods to keep: `catalog-api`, and `checkout` (it only has a ConfigMap volume; config-style volumes such as ConfigMap, Secret, projected and downwardAPI do not hold data).

3. Delete them:

   ```bash
   kubectl delete pod report-worker batch-runner payments-api -n prod
   ```

---

## Question 5: Remove the container runtime socket mount in `dev-ops`

Goal: no pod in `dev-ops` should mount `/run/containerd/containerd.sock` from the host.

1. Find the pods that mount the socket:

   ```bash
   kubectl get pods -n dev-ops -o yaml | grep -B3 -A3 "containerd.sock"
   kubectl get deploy -n dev-ops
   ```

   `billing` mounts the socket. `notifier` only mounts `/var/log` read-only and must not be changed.

2. Edit the `billing` Deployment and remove both the `volumeMounts` entry and the `volumes` entry (`hostPath: /run/containerd/containerd.sock`):

   ```bash
   kubectl edit deploy billing -n dev-ops
   kubectl rollout status deploy/billing -n dev-ops
   ```

3. Verify:

   ```bash
   kubectl get pods -n dev-ops -o yaml | grep containerd.sock     # nothing
   kubectl exec deploy/billing -n dev-ops -- ls -l /run/containerd/containerd.sock
   # ls: /run/containerd/containerd.sock: No such file or directory
   ```

Security rationale: the runtime socket gives root-equivalent control of the node (create privileged containers, read other containers' filesystems). Removing it enforces least privilege.

---

## Question 6: Enable Istio mTLS (STRICT) in `payments`

Goal: In namespace `payments`:

1. Ensure **automatic Istio sidecar injection** is enabled.
2. Enforce **mTLS in STRICT mode** for all workloads.
3. Confirm pods run with sidecars and communicate using mTLS.

### Step 1: Enable automatic sidecar injection

Check labels:

```bash
kubectl get namespace payments --show-labels
```

If necessary, enable injection:

```bash
kubectl label namespace payments istio-injection=enabled --overwrite
kubectl get namespace payments --show-labels
```

If existing pods were created **before** enabling injection, restart workloads:

```bash
kubectl rollout restart deployment -n payments payments-api
kubectl rollout restart deployment -n payments payments-worker
```

### Step 2: Enforce mTLS in STRICT mode with PeerAuthentication

Create `PeerAuthentication` in `payments`:

```yaml
apiVersion: security.istio.io/v1
kind: PeerAuthentication
metadata:
  name: payments-mtls-strict
  namespace: payments
spec:
  mtls:
    mode: STRICT
```

Apply it:

```bash
kubectl apply -f payments-mtls.yaml
```

### Step 3: Verify enforcement and sidecars

1. Confirm PeerAuthentication exists:
   - `kubectl get peerauthentication -n payments`
2. Confirm all pods have Envoy sidecars (e.g. containers `istio-proxy` present):
   - `kubectl get pods -n payments -o jsonpath='{range .items[*]}{.metadata.name}{": "}{.spec.containers[*].name}{"\n"}{end}'`
3. Optionally, test traffic between pods and use Istio tools (e.g. `istioctl proxy-config`) or logs to ensure mTLS is in effect.

Rationale:
- Sidecar injection provides Envoy proxies per pod.
- `PeerAuthentication` in `STRICT` mode requires mTLS; plaintext traffic is rejected.

---

## Question 7: Enforce AppArmor Profile on `{{NODE01}}`

Goal: load `nginx-profile-2` on `{{NODE01}}` and run `apparmor-pod` there with the profile enforced.

1. Load the prepared profile on `{{NODE01}}`:

   ```bash
   ssh {{NODE01}}
   cat /etc/apparmor.d/nginx_apparmor
   apparmor_parser -q /etc/apparmor.d/nginx_apparmor
   aa-status | grep -i nginx-profile-2
   exit
   ```

2. Update `/tmp/exam/cks-002-q7/pod.yaml` to reference the profile (Kubernetes 1.30+ field):

   ```yaml
   apiVersion: v1
   kind: Pod
   metadata:
     name: apparmor-pod
     namespace: apparmor
   spec:
     nodeName: {{NODE01}}
     containers:
     - name: busybox
       image: busybox:1.36.1
       command: ["sh", "-c", "sleep 3600"]
       securityContext:
         appArmorProfile:
           type: Localhost
           localhostProfile: nginx-profile-2
   ```

   ```bash
   kubectl apply -f /tmp/exam/cks-002-q7/pod.yaml
   ```

3. Verify:

   ```bash
   kubectl get pod apparmor-pod -n apparmor -o wide        # Running on {{NODE01}}
   kubectl exec apparmor-pod -n apparmor -- touch /tmp/x   # Permission denied
   ```

If the profile is not loaded on `{{NODE01}}`, the Pod does not start.

---

## Question 8: Re-secure the API Server

Goal: Ensure only authenticated, authorized REST requests are allowed.

1. Edit `/etc/kubernetes/manifests/kube-apiserver.yaml` on the control plane (`ssh {{CONTROL_PLANE}}`) and set the flags:

   ```yaml
   - --authorization-mode=Node,RBAC
   - --enable-admission-plugins=NodeRestriction
   ```

   Do not set `--anonymous-auth=false` on a kubeadm cluster: the kubelet's startup and liveness probes of the API server are anonymous, so the API server would never become ready. The access of anonymous users is removed with the ClusterRoleBinding below.

   The kubelet restarts the static pod; wait until `kubectl get pods -n kube-system` answers again.

2. Find and remove the ClusterRoleBinding that grants access to `system:anonymous`:

   ```bash
   kubectl get clusterrolebinding -o yaml | grep -B12 'name: system:anonymous'
   kubectl delete clusterrolebinding anonymous-admin
   ```

3. Verify:

   ```bash
   kubectl get pods -n kube-system
   curl -sk https://<api-server>:6443/api    # 401 Unauthorized
   ```

Anonymous requests no longer have any permission (they get 403/401).

---

## Question 9: Enable Audit Logging with Custom Rules

1. On the control plane (`ssh {{CONTROL_PLANE}}`), create the policy, for example `/etc/audit/audit-policy.yaml` (any path works). Rules are evaluated in order and the first match wins, so the specific rules come first. Resource names are the **plural** names (`cronjobs`):

   ```yaml
   apiVersion: audit.k8s.io/v1
   kind: Policy
   rules:
   - level: None
     users: ["system:kube-proxy"]
     verbs: ["watch"]
     resources:
     - group: ""
       resources: ["endpoints", "services"]
   - level: RequestResponse
     resources:
     - group: "batch"
       resources: ["cronjobs"]
   - level: Request
     namespaces: ["kube-system"]
     resources:
     - group: "apps"
       resources: ["deployments"]
   - level: Request
     resources:
     - group: ""
     - group: "extensions"
   ```

2. Edit `/etc/kubernetes/manifests/kube-apiserver.yaml`: add the flags, and mount the policy file and the log file into the static pod:

   ```yaml
   # command:
   - --audit-policy-file=/etc/audit/audit-policy.yaml
   - --audit-log-path=/var/log/kubernetes-logs.log
   - --audit-log-maxage=5
   - --audit-log-maxbackup=10
   - --audit-log-maxsize=100
   # volumeMounts:
   - mountPath: /etc/audit/audit-policy.yaml
     name: audit
     readOnly: true
   - mountPath: /var/log/kubernetes-logs.log
     name: audit-log
   # volumes:
   - name: audit
     hostPath:
       path: /etc/audit/audit-policy.yaml
       type: File
   - name: audit-log
     hostPath:
       path: /var/log/kubernetes-logs.log
       type: FileOrCreate
   ```

   The kubelet restarts the API server; wait until `kubectl get pods -n kube-system` answers again.

3. Verify by creating a CronJob and looking at the log:

   ```bash
   kubectl create cronjob test -n audit --image=busybox --schedule="0 0 1 1 *" -- true
   grep '"resource":"cronjobs"' /var/log/kubernetes-logs.log | tail -1 | jq '.level, (.responseObject != null)'   # "RequestResponse", true
   ```

---

## Question 10: Fix kube-bench findings

1. API server, on `{{CONTROL_PLANE}}` (`/etc/kubernetes/manifests/kube-apiserver.yaml`): add `--profiling=false` and replace `--service-account-lookup=false` by `--service-account-lookup=true` (or remove it):

   ```yaml
   - --profiling=false
   - --service-account-lookup=true
   ```

   The kubelet restarts the static pod; wait until `kubectl get pods -n kube-system` answers again.

2. kubelet on `{{NODE01}}` (`/var/lib/kubelet/config.yaml`):

   ```yaml
   authentication:
     anonymous:
       enabled: false
   authorization:
     mode: Webhook
   readOnlyPort: 0
   ```

   ```bash
   ssh {{NODE01}}
   systemctl restart kubelet
   exit
   kubectl get nodes     # {{NODE01}} Ready
   ```

3. etcd, on `{{CONTROL_PLANE}}` (`/etc/kubernetes/manifests/etcd.yaml`): replace `--auto-tls=true` and `--peer-auto-tls=true` by:

   ```yaml
   - --auto-tls=false
   - --peer-auto-tls=false
   ```

---

## Question 11: Enable Encryption at Rest for Secrets

1. On the control plane (`ssh {{CONTROL_PLANE}}`), create the configuration, for example `/etc/kubernetes/enc/enc.yaml` (any path works). **`aescbc` must be the first provider**: writes always use the first one, so `identity` first would store Secrets in plain text.

   ```yaml
   apiVersion: apiserver.config.k8s.io/v1
   kind: EncryptionConfiguration
   resources:
   - resources:
     - secrets
     providers:
     - aescbc:
         keys:
         - name: key1
           secret: <BASE64 OF 32 RANDOM BYTES>     # head -c 32 /dev/urandom | base64
     - identity: {}
   ```

2. Edit `/etc/kubernetes/manifests/kube-apiserver.yaml`: add the flag and mount the directory into the static pod:

   ```yaml
   # command:
   - --encryption-provider-config=/etc/kubernetes/enc/enc.yaml
   # volumeMounts:
   - name: enc
     mountPath: /etc/kubernetes/enc
     readOnly: true
   # volumes:
   - name: enc
     hostPath:
       path: /etc/kubernetes/enc
       type: DirectoryOrCreate
   ```

3. Verify with a new Secret read straight from etcd (existing Secrets stay plain until rewritten with `kubectl get secrets -A -o json | kubectl replace -f -`):

   ```bash
   kubectl create secret generic test --from-literal=k=v -n encryption
   crictl exec $(crictl ps --name etcd -q) etcdctl --endpoints=https://127.0.0.1:2379 \
     --cacert=/etc/kubernetes/pki/etcd/ca.crt --cert=/etc/kubernetes/pki/etcd/server.crt --key=/etc/kubernetes/pki/etcd/server.key \
     get /registry/secrets/encryption/test | hexdump -C | head      # starts with k8s:enc:aescbc:v1:key1
   ```

---

## Question 12: RuntimeClass `sandboxed` with gVisor

1. Create `/home/candidate/10/runtime-class.yaml`:

   ```yaml
   apiVersion: node.k8s.io/v1
   kind: RuntimeClass
   metadata:
     name: sandboxed
   handler: runsc
   ```

   ```bash
   kubectl apply -f /home/candidate/10/runtime-class.yaml
   ```

2. Update all Deployments in `server` namespace to use:

   ```yaml
   spec:
     template:
       spec:
         runtimeClassName: sandboxed
   ```

3. Verify:
   - `kubectl get pods -n server -o jsonpath='{range .items[*]}{.metadata.name}{": "}{.spec.runtimeClassName}{"\n"}{end}'` shows `sandboxed`.

---

## Question 13: Allow only trusted registries with a ValidatingAdmissionPolicy

1. Create the policy and the binding (`policy.yaml`):

   ```yaml
   apiVersion: admissionregistration.k8s.io/v1
   kind: ValidatingAdmissionPolicy
   metadata:
     name: trusted-registries
   spec:
     failurePolicy: Fail
     matchConstraints:
       resourceRules:
       - apiGroups: [""]
         apiVersions: ["v1"]
         operations: ["CREATE", "UPDATE"]
         resources: ["pods"]
     validations:
     - expression: >-
         object.spec.containers.all(c, c.image.startsWith('registry.k8s.io/')) &&
         (!has(object.spec.initContainers) ||
          object.spec.initContainers.all(c, c.image.startsWith('registry.k8s.io/')))
       message: "images must come from registry.k8s.io/"
   ---
   apiVersion: admissionregistration.k8s.io/v1
   kind: ValidatingAdmissionPolicyBinding
   metadata:
     name: trusted-registries-binding
   spec:
     policyName: trusted-registries
     validationActions: ["Deny"]
     matchResources:
       namespaceSelector:
         matchLabels:
           kubernetes.io/metadata.name: secure-apps
   ```

   ```bash
   kubectl apply -f policy.yaml
   ```

2. Verify (the policy takes a few seconds to become active):

   ```bash
   kubectl run bad  -n secure-apps --image=nginx:1.25 --restart=Never
   # Error from server (Forbidden): ... ValidatingAdmissionPolicy 'trusted-registries' ... images must come from registry.k8s.io/
   kubectl run good -n secure-apps --image=registry.k8s.io/pause:3.10 --restart=Never
   # pod/good created
   ```

---

## Question 14: Fix Deployment for Restricted Pod Security

1. Check the namespace enforces the profile:

   ```bash
   kubectl get ns secure-team --show-labels
   ```

2. Edit `/tmp/exam/cks-002-q14/insecure-deployment.yaml` to remove the violations:

   - `privileged: true` → remove it (or set `false`).
   - `runAsUser: 0` → `runAsNonRoot: true` and a non-root user (the image runs as UID 101).
   - `capabilities.add: ["NET_ADMIN"]` → `capabilities.drop: ["ALL"]`.
   - Add `allowPrivilegeEscalation: false` and `seccompProfile.type: RuntimeDefault`.
   - Replace the `hostPath` volume by an `emptyDir`.

   Container and volumes of the fixed manifest:

   ```yaml
   containers:
   - name: webapp
     image: nginxinc/nginx-unprivileged:1.27-alpine
     ports:
     - containerPort: 8080
     securityContext:
       runAsNonRoot: true
       runAsUser: 101
       allowPrivilegeEscalation: false
       capabilities:
         drop: ["ALL"]
       seccompProfile:
         type: RuntimeDefault
     volumeMounts:
     - mountPath: /data
       name: host-data
   volumes:
   - name: host-data
     emptyDir: {}
   ```

3. Apply and verify:

   ```bash
   kubectl apply -f /tmp/exam/cks-002-q14/insecure-deployment.yaml
   kubectl get pods -n secure-team      # Running
   ```

---

## Question 15: Scan images with Trivy and delete vulnerable Pods

1. List the images used in the namespace:

   ```bash
   kubectl get pods -n supply-chain -o custom-columns=NAME:.metadata.name,IMAGE:.spec.containers[*].image
   ```

2. Scan each image for CRITICAL vulnerabilities:

   ```bash
   trivy image --severity CRITICAL nginx:1.14.2
   trivy image --severity CRITICAL httpd:2.4.39
   trivy image --severity CRITICAL busybox:1.36.1
   ```

   `nginx:1.14.2` and `httpd:2.4.39` report CRITICAL vulnerabilities; `busybox:1.36.1` reports none.

3. Delete the vulnerable Pods and keep `tools`:

   ```bash
   kubectl delete pod legacy-web old-httpd -n supply-chain
   ```

4. Save the CRITICAL-only report for the `legacy-web` image:

   ```bash
   trivy image --severity CRITICAL nginx:1.14.2 > /tmp/exam/cks-002-q15/legacy-web-critical.txt
   ```

---

## Question 16: Detect `/dev/mem` Access with Falco and Stop the Offending Deployment

1. Create a Falco rule file (e.g. `/home/candidate/rule.yaml`):

   ```yaml
   - rule: read write below /dev/mem
     desc: An attempt to read or write to /dev/mem
     condition: >
       ((evt.is_open_read=true or evt.is_open_write=true) and fd.name contains /dev/mem)
     output: "Process %proc.name accessed /dev/mem (pod=%k8s.pod.name ns=%k8s.ns.name)"
     priority: WARNING
     tags: [security]
   ```

2. Falco runs on the nodes: run it on the node where the workloads are scheduled (the rule file has to be on that node). Find the nodes with `kubectl get pods -n batch-ops -o wide`; try each one if needed:

   ```bash
   scp /home/candidate/rule.yaml <node>:/tmp/rule.yaml
   ssh <node> 'timeout 30 falco -r /tmp/rule.yaml' | grep -i 'dev/mem'
   ```

   The output names the offending pod, e.g. `telemetry-agent-xxxxx` in `batch-ops`.

3. Find the owning Deployment and scale it down; leave `image-resizer` and `email-sender` running:

   ```bash
   kubectl get pod telemetry-agent-xxxxx -n batch-ops -o jsonpath='{.metadata.ownerReferences[0].name}'   # the ReplicaSet, named after the Deployment
   kubectl scale deployment telemetry-agent -n batch-ops --replicas=0
   ```

`telemetry-agent` should show `0/0` replicas.
