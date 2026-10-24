# CKS Practice Lab 5 - Answer key

Commands were run against the lab cluster (kubeadm, three nodes: `{{CONTROL_PLANE}}`, `{{NODE01}}`, `{{NODE02}}`).
The lab registry used by Q5 and Q6 is a plain HTTP registry on a NodePort of the cluster; its address
is in the `registry.txt` of each question.

---

## Question 1: hardened Deployment (`sandbox`)

```bash
kubectl -n sandbox edit deployment build-agent
```

```yaml
      containers:
      - name: agent
        image: nginxinc/nginx-unprivileged:1.27-alpine
        securityContext:
          runAsUser: 65535
          allowPrivilegeEscalation: false
          readOnlyRootFilesystem: true
          capabilities:
            drop: ["ALL"]
        volumeMounts:
        - {name: tmp, mountPath: /tmp}
      volumes:
      - {name: tmp, emptyDir: {}}
```

A read-only root filesystem needs a writable `emptyDir` for `/tmp` (nginx writes its pid file and caches there), otherwise the Pods crash.

## Question 2: who can read Secrets? (`rbac-audit`)

```bash
for sa in $(kubectl -n rbac-audit get sa -o jsonpath='{.items[*].metadata.name}'); do
  echo "$sa: $(kubectl auth can-i get secrets -n rbac-audit --as=system:serviceaccount:rbac-audit:$sa)"
done
# reader-sa, batch-sa (wildcard Role) and ops-sa (built-in ClusterRole "edit") can
printf 'batch-sa\nops-sa\nreader-sa\n' > /tmp/exam/cks-005-q2/secret-readers.txt

kubectl -n rbac-audit delete rolebinding batch-bind ops-bind
kubectl -n rbac-audit create role cm-reader --verb=get,list --resource=configmaps
kubectl -n rbac-audit create rolebinding cm-bind --role=cm-reader --serviceaccount=rbac-audit:batch-sa --serviceaccount=rbac-audit:ops-sa
```

`kubectl get role,rolebinding -o yaml | grep secrets` misses the wildcard Role and the built-in ClusterRole: `can-i` is the reliable check.

## Question 3: ingress policy (`staging`)

```bash
kubectl apply -f - <<'EOF'
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata: {name: allow-np, namespace: staging}
spec:
  podSelector: {}
  policyTypes: [Ingress]
  ingress:
  - from:
    - podSelector: {}
    ports:
    - {protocol: TCP, port: 80}
EOF
```

`from: podSelector: {}` selects the Pods of the policy's own namespace only; the policy selects every Pod, so port 8080 is denied too.

## Question 4: exposed Services (`exposed-lab`)

```bash
kubectl -n exposed-lab get svc
kubectl -n exposed-lab patch svc reports -p '{"spec":{"type":"ClusterIP"}}'
kubectl -n exposed-lab patch svc admin -p '{"spec":{"type":"ClusterIP"}}'
```

`portal` stays a NodePort Service (annotation `exposure: public`).

## Question 5: verify signatures and pin by digest

```bash
cd /tmp/exam/cks-005-q5
REG=$(cat registry.txt)
for t in v1.0 v1.1 v1.2; do
  cosign verify --key cosign.pub --insecure-ignore-tlog=true $REG/payments:$t >/dev/null 2>&1 && echo "$t: VALID" || echo "$t: not valid"
done
echo <the valid tag> > verified-tags.txt
curl -sI -H 'Accept: application/vnd.oci.image.manifest.v1+json, application/vnd.docker.distribution.manifest.v2+json' http://$REG/v2/payments/manifests/<tag> | grep -i docker-content-digest
sed -i "s#payments:v1.2#payments@sha256:<digest>#" deployment.yaml
```

(`cosign triangulate`/`cosign verify` print the digest of the verified image as well.) A tag is mutable; a digest is not.

## Question 6: sign an image

```bash
cd /tmp/exam/cks-005-q6
REG=$(cat registry.txt)
COSIGN_PASSWORD="" cosign generate-key-pair
COSIGN_PASSWORD="" cosign sign --yes --tlog-upload=false --key cosign.key $REG/internal-tools:1.0
cosign verify --key cosign.pub --insecure-ignore-tlog=true $REG/internal-tools:1.0
```

## Question 7: strace of a container process (`trace-lab`)

```bash
kubectl -n trace-lab get pod ledger-sync -o wide        # runs on {{NODE02}}
ssh {{NODE02}}
CID=$(crictl ps --name sync -q); PID=$(crictl inspect $CID | jq .info.pid)
strace -f -e trace=openat,connect -p $PID 2>&1 | grep -E 'state.tok|sin_addr'
# openat(... "/var/run/.sync-NNNN/state.tok", O_WRONLY|O_CREAT|O_TRUNC ...)
# connect(3, {sa_family=AF_INET, sin_port=htons(PORT), sin_addr=inet_addr("IP")}, 16)
exit
echo '/var/run/.sync-NNNN/state.tok' > /tmp/exam/cks-005-q7/file.txt
echo 'IP:PORT' > /tmp/exam/cks-005-q7/endpoint.txt
```

`-f` follows the processes that the shell loop spawns (`cat`, `nc`).

## Question 8: suspicious process on `{{NODE02}}`

```bash
ssh {{NODE02}}
ss -tnp state syn-sent                                   # shows the peer and the process
PID=$(pgrep -f dbus-helper | head -1)
timeout 10 strace -f -e trace=connect -p $PID 2>&1 | grep sin_addr
pgrep -af dbus-helper                                       # shows the script: /var/tmp/.ckx-sysd/dbus-helper
kill $(pgrep -f dbus-helper)
exit
echo '<IP>:<PORT>' > /tmp/exam/cks-005-q8/endpoint.txt
```

Collect the address first (a stopped process cannot be traced), then stop the process.

## Question 9: audit log forensics

```bash
cd /tmp/exam/cks-005-q9
grep '"delete"' audit.log | grep payment-gateway-key | grep '"code":200'     # one event: the user is in "username", the address in "sourceIPs"
jq -r 'select(.verb=="delete" and .objectRef.name=="payment-gateway-key" and .responseStatus.code==200) | .user.username, .sourceIPs[0]' audit.log
echo '<user>' > who.txt
echo '<ip>' > ip.txt
```

`403` events are attempts that were denied; reads by other users and deletes of other Secrets are noise.

## Question 10: ImagePolicyWebhook

```bash
ssh {{CONTROL_PLANE}}
cd /etc/kubernetes/policywebhook
cat admission_config.json kubeconfig.yaml
```

Three mistakes: `kubeConfigFile` points to `external-kubeconfig.yml` (the file is `kubeconfig.yaml`), `defaultAllow` is `true` (must be `false`), and the server URL of `kubeconfig.yaml` uses port 8444 (the backend listens on 8443).

```bash
sed -i 's#external-kubeconfig.yml#kubeconfig.yaml#; s#"defaultAllow": true#"defaultAllow": false#' admission_config.json
sed -i 's#8444#8443#' kubeconfig.yaml
vi /etc/kubernetes/manifests/kube-apiserver.yaml
```

```yaml
    - --enable-admission-plugins=NodeRestriction,ImagePolicyWebhook
    - --admission-control-config-file=/etc/kubernetes/policywebhook/admission_config.json
    ...
    volumeMounts:
    - {name: policywebhook, mountPath: /etc/kubernetes/policywebhook, readOnly: true}
  volumes:
  - name: policywebhook
    hostPath: {path: /etc/kubernetes/policywebhook, type: DirectoryOrCreate}
```

Wait for the API server to restart (if it does not come back, `crictl ps -a` / `crictl logs` show the plugin error). Check:

```bash
kubectl run t --image=nginx:latest -n image-policy --dry-run=server     # denied by the image policy webhook
kubectl run t --image=nginx:1.27 -n image-policy --dry-run=server       # accepted
```

If the API server starts with a wrong configuration file path it never becomes healthy; with the wrong port and `defaultAllow: false` it starts but every Pod (including the mirror Pods of the static Pods) is rejected.

## Question 11: kubelet `seccompDefault` on `{{NODE02}}`

```bash
ssh {{NODE02}}
sed -i '$a seccompDefault: true' /var/lib/kubelet/config.yaml     # or yq -i '.seccompDefault = true'
systemctl restart kubelet && systemctl is-active kubelet
exit
kubectl apply -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata: {name: probe, namespace: kubelet-lab}
spec:
  nodeName: {{NODE02}}
  containers: [{name: c, image: "busybox:1.36.1", command: ["sleep", "3600"]}]
EOF
kubectl -n kubelet-lab exec probe -- grep Seccomp /proc/1/status       # Seccomp: 2
```

Pods that existed before the kubelet restart keep their old (unconfined) state; only new containers get the default profile.

## Question 12: Istio AuthorizationPolicy (`mesh-lab`)

```bash
kubectl apply -f - <<'EOF'
apiVersion: security.istio.io/v1
kind: AuthorizationPolicy
metadata: {name: orders-allow, namespace: mesh-lab}
spec:
  selector: {matchLabels: {app: orders}}
  action: ALLOW
  rules:
  - from: [{source: {principals: ["cluster.local/ns/mesh-lab/sa/frontend"]}}]
    to: [{operation: {methods: ["GET"]}}]
EOF
```

An ALLOW policy denies everything that does not match one of its rules (403 `RBAC: access denied`).

## Question 13: ServiceAccount and Role (`test-system`)

```bash
kubectl -n test-system get pod nginx-pod -o jsonpath='{.spec.serviceAccountName}' > /tmp/exam/cks-005-q13/sa-name.txt
kubectl -n test-system create role deploy-reader --verb=get,list,watch --resource=deployments
kubectl -n test-system create rolebinding deploy-reader-bind --role=deploy-reader --serviceaccount=test-system:sa-dev-1
```

## Question 14: Falco rule order (`falco-lab`)

Run it once and look at the output: every line of `invoice` is reported by the broad rule (`BROAD | pod=invoice ...`) and no line has the format of `Invoice process`.

```bash
ssh {{NODE01}}
cd /tmp/exam/cks-005-q14
timeout 15 falco -c falco.yaml 2>&1 | head
grep -n rule_matching falco.yaml          # rule_matching: first
```

With `rule_matching: first` (the default) Falco stops at the **first** rule of the rules file that matches an event. The broad rule `Any process in falco-lab` comes first and matches every process of the namespace, so it consumes the events of `invoice` and `Invoice process` never fires. Any of these fixes is valid:

1. Put `Invoice process` **before** the broad rule in `rules.yaml` (more specific rules first):

   ```yaml
   - rule: Invoice process
     ...
   - rule: Any process in falco-lab
     ...
   ```

2. Narrow the broad rule so that it no longer matches `invoice`: add `and k8s.pod.name != invoice` to its condition.
3. Set `rule_matching: all` in `falco.yaml` (every matching rule reports the event; the events of `invoice` are then reported twice, once per rule).

Then record 30+ seconds:

```bash
timeout 35 falco -c /tmp/exam/cks-005-q14/falco.yaml > /tmp/exam/cks-005-q14/events
grep -c ',whoami$' /tmp/exam/cks-005-q14/events        # about 8 lines of Invoice process
```

(The file may also contain lines of the broad rule for `mailer`: they are ignored.) Deleting the broad rule makes the rule for `invoice` fire, but the broad rule has to keep reporting the other Pods, so that is not a valid fix.

## Question 15: Traefik middlewares (`traefik-lab`)

Two Ingress objects, because the middleware annotation applies to the whole Ingress:

```yaml
apiVersion: traefik.io/v1alpha1
kind: Middleware
metadata: {name: strip-reports, namespace: traefik-lab}
spec:
  stripPrefix:
    prefixes: ["/reports"]
---
apiVersion: traefik.io/v1alpha1
kind: Middleware
metadata: {name: legacy-redirect, namespace: traefik-lab}
spec:
  redirectRegex:
    regex: "^https?://[^/]+/legacy/(.*)"
    replacement: "/reports/${1}"
    permanent: true
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: reports
  namespace: traefik-lab
  annotations:
    traefik.ingress.kubernetes.io/router.middlewares: traefik-lab-strip-reports@kubernetescrd
spec:
  ingressClassName: traefik
  rules:
  - host: lab.example.com
    http:
      paths:
      - {path: /reports, pathType: Prefix, backend: {service: {name: reports, port: {number: 80}}}}
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: legacy
  namespace: traefik-lab
  annotations:
    traefik.ingress.kubernetes.io/router.middlewares: traefik-lab-legacy-redirect@kubernetescrd
spec:
  ingressClassName: traefik
  rules:
  - host: lab.example.com
    http:
      paths:
      - {path: /legacy, pathType: Prefix, backend: {service: {name: reports, port: {number: 80}}}}
```

Without `stripPrefix` the application receives `/reports/health.txt` and answers 404. The `legacy` Ingress needs a backend even though the middleware answers first; `permanent: true` gives 301.

### Traefik middleware cheat sheet (the Traefik documentation is not available in an exam)

A `Middleware` is a Traefik CRD (`apiVersion: traefik.io/v1alpha1`, `kind: Middleware`). An Ingress uses it through an annotation, with the name `<namespace>-<middleware-name>@kubernetescrd`; several middlewares are chained with commas and run in that order. **The annotation applies to every path of the Ingress**: when two paths need different middlewares, use two Ingress objects.

```yaml
metadata:
  annotations:
    traefik.ingress.kubernetes.io/router.middlewares: myns-strip@kubernetescrd,myns-headers@kubernetescrd
```

| Need | `spec` of the Middleware |
|---|---|
| HTTP to HTTPS | `redirectScheme: {scheme: https, permanent: true}` |
| Redirect by regex | `redirectRegex: {regex: "^https?://[^/]+/old/(.*)", replacement: "/new/${1}", permanent: true}` |
| Remove a path prefix | `stripPrefix: {prefixes: ["/app"]}` (also `stripPrefixRegex: {regex: ["^/app/[0-9]+"]}`) |
| Add a path prefix | `addPrefix: {prefix: "/v2"}` |
| Rewrite the path | `replacePath: {path: "/new"}` / `replacePathRegex: {regex: "^/old/(.*)", replacement: "/new/$1"}` |
| Request/response headers | `headers: {customRequestHeaders: {X-Foo: bar}, customResponseHeaders: {X-Robots-Tag: noindex}}` |
| Basic authentication | `basicAuth: {secret: users-secret}` (Secret key `users`, htpasswd format) |
| Allow only some clients | `ipAllowList: {sourceRange: ["10.0.0.0/8"]}` (`ipWhiteList` in old versions) |
| Limit the request rate | `rateLimit: {average: 10, burst: 20}` |

Check with `curl -s -o /dev/null -D - --resolve host:80:<traefik-ip> http://host/path` (`kubectl get svc -n traefik`) and look at the status code and the `Location` header.

How to find or check the annotation without the Traefik documentation:

- Remember the three parts: the prefix `traefik.ingress.kubernetes.io/` (like `nginx.ingress.kubernetes.io/`), the key `router.middlewares`, and the value `<namespace>-<name>@kubernetescrd`. Traefik names every object `<name>@<provider>`; the provider of the CRDs is `kubernetescrd` and the CRD provider prefixes the name with the namespace.
- Feedback loop: `kubectl logs -n traefik deploy/traefik --since=1m | grep -i middleware`. A wrong reference is logged as `middleware "strip@kubernetescrd" does not exist`, which shows the name that Traefik looked for. A wrong annotation key (for example `router.middleware` without the final `s`) is logged as `Failed to parse annotations ... field not found, node: middleware`. `kubectl describe ingress` shows no events for these problems: Traefik writes to its own log, not to Kubernetes events.
- The fields of a Middleware come from the cluster: `kubectl api-resources | grep traefik`, `kubectl explain middleware.spec --recursive`, `kubectl explain middleware.spec.stripPrefix`.
- Without the annotation: an `IngressRoute` references middlewares by fields that `kubectl explain ingressroute.spec.routes --recursive` shows (`middlewares: [{name, namespace}]`, `match: Host(...) && PathPrefix(...)`, `services`), so nothing has to be remembered about `@kubernetescrd`.

---

## Notes on this lab

- Q1, Q3, Q13 are adaptations of the source text (`cks-5.txt`) with their own namespaces; the PodSecurityPolicy question of the source was replaced (PSP no longer exists) and the default-namespace questions were moved to exclusive namespaces.
- Q5, Q6 (cosign) need the lab registry, which the setup starts in the namespace `ckx-registry`; the signatures are made without a transparency log (`--tlog-upload=false`) so that nothing is published to the public Rekor log.
- Q7, Q8 (strace) use addresses of the documentation ranges (RFC 5737), which are never routed.
- Q14 uses a standalone Falco run (`falco -c /tmp/exam/cks-005-q14/falco.yaml`), not the Falco service; its Pods run `whoami` and `hostname`, which already exist in the image (a binary created at run time would trigger Falco's default drift rule, which is a different story). The validators start Falco themselves for 16 seconds with the candidate's configuration.
- Q10 changes the API server (the webhook backend is a small python process on the control plane under `/var/tmp/.ckx-webhook`): the checkpoint restore puts the manifest back, removes `/etc/kubernetes/policywebhook` and stops the backend.
