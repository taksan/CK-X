# CKS Practice Lab 3 - Answer key

Every command below was run against the lab cluster (kubeadm, three nodes). Namespaces,
file locations and names are the ones used by the questions.

---

## Question 1: AppArmor profile on `{{NODE02}}`

1. Load the prepared profile on `{{NODE02}}`:

   ```bash
   ssh {{NODE02}}
   cat /etc/apparmor.d/nginx_apparmor
   apparmor_parser -q /etc/apparmor.d/nginx_apparmor
   aa-status | grep nginx-deny
   exit
   ```

2. In `/tmp/exam/cks-003-q1/pod.yaml` reference the profile (Kubernetes 1.30+). It can be set on the container or, like here, on the Pod:

   ```yaml
   apiVersion: v1
   kind: Pod
   metadata:
     name: app-runner
     namespace: profile-lab
   spec:
     nodeName: {{NODE02}}
     securityContext:
       appArmorProfile:
         type: Localhost
         localhostProfile: nginx-deny
     containers:
     - name: app
       image: busybox:1.36.1
       command: ["sh", "-c", "sleep 3600"]
   ```

   ```bash
   kubectl apply -f /tmp/exam/cks-003-q1/pod.yaml
   ```

3. Verify:

   ```bash
   kubectl get pod app-runner -n profile-lab -o wide        # Running on {{NODE02}}
   kubectl exec app-runner -n profile-lab -- touch /tmp/x   # Permission denied
   ```

If the profile is not loaded on `{{NODE02}}`, the Pod does not start.

---

## Question 2: Audit logging with custom rules

1. On the control plane (`ssh {{CONTROL_PLANE}}`) create the policy, for example `/etc/audit/audit-policy.yaml` (any path works). Rules are evaluated in order and the **first match wins**: `pods/portforward` and `services/proxy` belong to the core group, so their `Metadata` rule must come **before** the general core `Request` rule.

   ```yaml
   apiVersion: audit.k8s.io/v1
   kind: Policy
   omitStages:
   - "RequestReceived"
   rules:
   - level: RequestResponse
     resources:
     - group: ""
       resources: ["namespaces"]
   - level: Request
     namespaces: ["kube-system"]
     resources:
     - group: ""
       resources: ["secrets"]
   - level: Metadata
     resources:
     - group: ""
       resources: ["pods/portforward", "services/proxy"]
   - level: Request
     resources:
     - group: ""
     - group: "extensions"
   - level: Metadata
   ```

2. Edit `/etc/kubernetes/manifests/kube-apiserver.yaml`: add the flags, and mount the policy file and the log **directory** into the static pod:

   ```yaml
   # command:
   - --audit-policy-file=/etc/audit/audit-policy.yaml
   - --audit-log-path=/var/log/kubernetes-logs.log
   - --audit-log-maxage=12
   - --audit-log-maxbackup=8
   - --audit-log-maxsize=200
   # volumeMounts:
   - mountPath: /etc/audit/audit-policy.yaml
     name: audit
     readOnly: true
   - mountPath: /var/log
     name: audit-log
   # volumes:
   - name: audit
     hostPath:
       path: /etc/audit/audit-policy.yaml
       type: File
   - name: audit-log
     hostPath:
       path: /var/log
       type: DirectoryOrCreate
   ```

   Mount the **directory**, not the single log file: rotation renames the file, which cannot be done on a bind-mounted file, so auditing would silently stop at the first rotation. The kubelet restarts the API server; wait until `kubectl get pods -n kube-system` answers again.

3. Verify:

   ```bash
   tail -3 /var/log/kubernetes-logs.log | jq '.level, .stage'
   ```

---

## Question 3: Scan images with Trivy

```bash
mkdir -p /tmp/exam/cks-003-q3 && cd /tmp/exam/cks-003-q3
for img in httpd:2.4.49 postgres:12 alpine:3.12; do
  trivy image --severity HIGH,CRITICAL "$img" >> trivy-vulnerable.txt
done
grep -c CVE- trivy-vulnerable.txt
```

`--severity HIGH,CRITICAL` hides MEDIUM and LOW findings. Using `>>` (append) keeps the three scans in one file.

---

## Question 4: Falco on `{{NODE02}}`

1. Create a rule file on `{{NODE02}}`, for example `/tmp/exam/cks-003-q4/rule.yaml`. `-r` replaces the configured rule files, so the default macros (`spawned_process`, `container`) are not available: use the raw conditions. The field `%evt.time.iso8601` is the ISO 8601 timestamp (`%evt.time` is only the time of day).

   ```yaml
   - rule: Process spawned in container
     desc: A new process was started in a container
     condition: evt.type in (execve, execveat) and evt.dir=< and container.id != host
     output: "%evt.time.iso8601,%user.name,%proc.name"
     priority: WARNING
   ```

2. Run Falco on `{{NODE02}}` for at least 30 seconds, writing to the file:

   ```bash
   ssh {{NODE02}}
   timeout 40 falco -r /tmp/exam/cks-003-q4/rule.yaml \
     -o stdout_output.enabled=false \
     -o file_output.enabled=true -o file_output.keep_alive=false \
     -o file_output.filename=/tmp/exam/cks-003-q4/alerts/details
   ```

   Alternatively set `file_output` in `/etc/falco/falco.yaml`, add the rule to `/etc/falco/falco_rules.local.yaml` and restart the service (`systemctl restart falco-modern-bpf`).

3. Verify the file (`whoami` is the process the Pod `beacon` spawns every few seconds):

   ```bash
   grep -c whoami /tmp/exam/cks-003-q4/alerts/details
   ```

   Pitfall: Falco evaluates the rules with `rule_matching: first`, so when the default rule files are loaded an earlier default rule (for example "Executing binary not part of base image", which fires for binaries created after the container started) can report an event first and your own rule never sees it. Compare the result with what really runs on the node (`ps`, `crictl`) and do not grep for the output of one rule only; `rule_matching: all` in `falco.yaml` or `-r` with your own file avoid the masking.

---

## Question 5: NetworkPolicy `restricted-policy`

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: restricted-policy
  namespace: dev-team
spec:
  podSelector:
    matchLabels:
      app: products-service
  policyTypes:
  - Ingress
  ingress:
  - from:
    - podSelector: {}                  # every Pod of dev-team
  - from:
    - namespaceSelector: {}            # in any namespace ...
      podSelector:
        matchLabels:
          environment: testing         # ... with this label
```

Find the labels first with `kubectl get pod products-service -n dev-team --show-labels`. Verify:

```bash
IP=$(kubectl get pod products-service -n dev-team -o jsonpath='{.status.podIP}')
kubectl exec -n dev-team orders-client -- wget -q -T 3 -O /dev/null http://$IP   # works
kubectl exec -n qa-team tester -- wget -q -T 3 -O /dev/null http://$IP           # works
kubectl exec -n qa-team visitor -- wget -q -T 3 -O /dev/null http://$IP          # times out
```

Note `from: [- podSelector: {}, - namespaceSelector: ..., podSelector: ...]` in a **single** `from` list is equivalent; a `namespaceSelector` and a `podSelector` in the **same** list item must both match.

---

## Question 6: kubesec

```bash
kubesec scan /tmp/exam/cks-003-q6/kubesec-test.yaml     # score -36, critical findings
```

The critical findings are `capabilities.add: SYS_ADMIN` and `allowPrivilegeEscalation: true`. Edit the manifest:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: kubesec-demo
spec:
  containers:
  - name: kubesec-demo
    image: gcr.io/google-samples/node-hello:1.0
    securityContext:
      runAsUser: 1000
      runAsNonRoot: true
      allowPrivilegeEscalation: false
      readOnlyRootFilesystem: true
      capabilities:
        drop:
        - ALL
```

```bash
kubesec scan /tmp/exam/cks-003-q6/kubesec-test.yaml     # score 4, no critical finding
```

---

## Question 7: RuntimeClass `untrusted` (gVisor)

```bash
kubectl apply -f - <<EOF
apiVersion: node.k8s.io/v1
kind: RuntimeClass
metadata:
  name: untrusted
handler: runsc
EOF

kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: untrusted
  namespace: sandbox
spec:
  nodeName: {{NODE02}}
  runtimeClassName: untrusted
  containers:
  - name: untrusted
    image: alpine:3.18
    command: ["/bin/sh", "-c", "sleep 3600"]
EOF

kubectl wait --for=condition=Ready pod/untrusted -n sandbox
kubectl exec untrusted -n sandbox -- dmesg > /tmp/exam/cks-003-q7/untrusted-dmesg.txt
head -3 /tmp/exam/cks-003-q7/untrusted-dmesg.txt          # "Starting gVisor..."
```

The cluster also has a RuntimeClass named `gvisor`; the question asks for one named `untrusted`.

---

## Question 8: Pod Security `baseline` and RBAC in `staging`

```bash
kubectl label namespace staging pod-security.kubernetes.io/enforce=baseline

kubectl create serviceaccount deployer-sa -n staging
kubectl create role pod-manager -n staging --verb=create,get,list,delete --resource=pods
kubectl create rolebinding pod-manager-binding -n staging --role=pod-manager --serviceaccount=staging:deployer-sa
```

Verify, impersonating the ServiceAccount (the second command is rejected by Pod Security, not by RBAC):

```bash
kubectl run ok -n staging --image=busybox --restart=Never --dry-run=server --as system:serviceaccount:staging:deployer-sa
kubectl run bad -n staging --image=busybox --restart=Never --dry-run=server --as system:serviceaccount:staging:deployer-sa \
  --overrides='{"spec":{"containers":[{"name":"bad","image":"busybox","securityContext":{"privileged":true}}]}}'
kubectl auth can-i create deployments -n staging --as system:serviceaccount:staging:deployer-sa   # no
```

---

## Question 9: User `john`

```bash
openssl genrsa -out john.key 2048
openssl req -new -key john.key -out john.csr -subj "/CN=john/O=devs"

cat <<EOF | kubectl apply -f -
apiVersion: certificates.k8s.io/v1
kind: CertificateSigningRequest
metadata:
  name: john-csr
spec:
  request: $(base64 -w0 < john.csr)
  signerName: kubernetes.io/kube-apiserver-client
  expirationSeconds: 86400
  usages:
  - client auth
EOF

kubectl certificate approve john-csr
kubectl get csr john-csr -o jsonpath='{.status.certificate}' | base64 -d > john.crt
openssl x509 -in john.crt -noout -subject

kubectl create role john-role -n john --verb=list,get,create,delete --resource=pods,secrets
kubectl create rolebinding john-role-binding -n john --role=john-role --user=john

kubectl auth can-i create pods -n john --as john            # yes
kubectl auth can-i create deployments -n john --as john     # no
```

---

## Question 10: Ingress with TLS (Traefik)

```bash
kubectl create secret tls bingo-tls -n web-tls \
  --cert=/tmp/exam/cks-003-q10/bingo.crt --key=/tmp/exam/cks-003-q10/bingo.key

kubectl run shop-web -n web-tls --image=nginx --port=80 --expose
```

Traefik redirects HTTP to HTTPS with a `Middleware` (a CRD of Traefik) that the Ingress references in an annotation (`<namespace>-<name>@kubernetescrd`):

```yaml
apiVersion: traefik.io/v1alpha1
kind: Middleware
metadata:
  name: https-redirect
  namespace: web-tls
spec:
  redirectScheme:
    scheme: https
    permanent: true
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: bingo
  namespace: web-tls
  annotations:
    traefik.ingress.kubernetes.io/router.middlewares: web-tls-https-redirect@kubernetescrd
spec:
  ingressClassName: traefik
  tls:
  - hosts:
    - bingo.com
    secretName: bingo-tls
  rules:
  - host: bingo.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: shop-web
            port:
              number: 80
```

Verify through the controller address (`kubectl get svc -n traefik`):

```bash
curl -sI --resolve bingo.com:80:<ADDRESS> http://bingo.com/                # 301 -> https://bingo.com/
curl -sk --resolve bingo.com:443:<ADDRESS> https://bingo.com/ | head -3    # nginx page
```

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

With ingress-nginx instead of Traefik, an Ingress with a `tls` section already redirects HTTP to HTTPS (annotation `nginx.ingress.kubernetes.io/ssl-redirect: "true"`).

---

## Question 11: CIS findings

1. kubelet on `{{NODE02}}` (`ssh {{NODE02}}`, `/var/lib/kubelet/config.yaml`):

   ```yaml
   authentication:
     anonymous:
       enabled: false
   authorization:
     mode: Webhook
   readOnlyPort: 0
   ```

   ```bash
   systemctl restart kubelet
   ```

2. etcd, on `{{CONTROL_PLANE}}` (`/etc/kubernetes/manifests/etcd.yaml`): set `--client-cert-auth=true` and replace `--auto-tls=true` by `--auto-tls=false`.

3. On `{{CONTROL_PLANE}}`, add `- --profiling=false` to the `command` of `/etc/kubernetes/manifests/kube-controller-manager.yaml` and `/etc/kubernetes/manifests/kube-scheduler.yaml`.

The kubelet restarts the static pods; wait until `kubectl get pods -n kube-system` shows them `1/1` again.

---

## Question 12: Secrets in `safe`

```bash
mkdir -p /tmp/exam/cks-003-q12
kubectl get secret admin -n safe -o jsonpath='{.data.username}' | base64 -d > /tmp/exam/cks-003-q12/username.txt
kubectl get secret admin -n safe -o jsonpath='{.data.password}' | base64 -d > /tmp/exam/cks-003-q12/password.txt

kubectl create secret generic newsecret -n safe --from-literal=username=dbadmin --from-literal=password=moresecurepas

cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: db-client
  namespace: safe
spec:
  containers:
  - name: client
    image: redis
    volumeMounts:
    - name: secret-vol
      mountPath: /etc/mysecret
      readOnly: true
  volumes:
  - name: secret-vol
    secret:
      secretName: newsecret
EOF

kubectl exec db-client -n safe -- ls /etc/mysecret
```

---

## Question 13: Service on port 389

```bash
ssh {{NODE02}}
sudo -i

ss -ltnp | grep ':389 '                                  # users:(("ldapd",pid=1234,fd=3))
ls -l /proc/1234/fd | awk '{print $NF}' > /tmp/exam/cks-003-q13/files.txt     # or: lsof -p 1234 > ...
readlink -f /proc/1234/exe                               # /usr/local/sbin/ldapd

kill 1234
rm /usr/local/sbin/ldapd
```

Save the list **before** stopping the service. The executable is found through `/proc/<pid>/exe`: do not delete anything else.

---

## Question 14: RBAC for `sa-dev-1`

1. Find the Role bound to `sa-dev-1` (not `ops-access`, which belongs to `sa-ops`):

   ```bash
   kubectl get rolebindings -n security -o wide
   kubectl edit role dev-access -n security
   ```

   ```yaml
   rules:
   - apiGroups: [""]
     resources: ["services"]
     verbs: ["watch"]
   ```

2. Create the ClusterRole and the binding:

   ```bash
   kubectl create clusterrole role-2 --verb=update --resource=namespaces
   kubectl create clusterrolebinding role-2-binding --clusterrole=role-2 --serviceaccount=security:sa-dev-1
   ```

3. Verify:

   ```bash
   kubectl auth can-i watch services -n security --as system:serviceaccount:security:sa-dev-1   # yes
   kubectl auth can-i list services -n security --as system:serviceaccount:security:sa-dev-1    # no
   kubectl auth can-i update namespaces --as system:serviceaccount:security:sa-dev-1            # yes
   ```

---

## Question 15: Projected ServiceAccount token

```bash
kubectl create serviceaccount api-client -n projected-tokens
kubectl patch serviceaccount api-client -n projected-tokens -p '{"automountServiceAccountToken": false}'
```

A Pod's ServiceAccount cannot be changed in place: delete and recreate `token-demo`:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: token-demo
  namespace: projected-tokens
spec:
  serviceAccountName: api-client
  containers:
  - name: web
    image: nginx:1.27-alpine
    volumeMounts:
    - name: tok
      mountPath: /var/run/secrets/tokens
      readOnly: true
  volumes:
  - name: tok
    projected:
      sources:
      - serviceAccountToken:
          path: token.jwt
          expirationSeconds: 600
          audience: https://kubernetes.default.svc.cluster.local
```

Verify the claims (subject, audience, lifetime):

```bash
kubectl exec token-demo -n projected-tokens -- cat /var/run/secrets/tokens/token.jwt | cut -d. -f2 | tr '_-' '/+' | base64 -d 2>/dev/null | jq '{sub, aud, lifetime: (.exp - .iat)}'
```

---

## Question 16: Verify binaries with a checksum

```bash
cd /tmp/exam/cks-003-q16
cat checksums.txt                                        # <sha256>  kubectl
sha256sum kubectl-a kubectl-b
echo "$(cut -d' ' -f1 checksums.txt)  kubectl-a" | sha256sum -c -
echo "$(cut -d' ' -f1 checksums.txt)  kubectl-b" | sha256sum -c -
rm kubectl-b                                             # the one reported as FAILED
```
