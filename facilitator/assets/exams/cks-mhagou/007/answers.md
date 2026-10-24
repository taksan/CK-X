# CKS - MHagou - Exam 7 - Answer key

Commands were run against the lab cluster (kubeadm, `{{CONTROL_PLANE}}`, `{{NODE01}}`, `{{NODE02}}`). Namespaces, names and
file locations are the ones of the questions. The source labs were adapted (see the notes at the end).

---

## Question 1: Service exposed outside the cluster (`exposure-lab`)

```bash
kubectl -n exposure-lab get svc nginx-external          # NodePort 80:3xxxx
kubectl -n exposure-lab patch svc nginx-external -p '{"spec":{"type":"ClusterIP"}}'
kubectl -n exposure-lab get svc nginx-external          # ClusterIP, 80/TCP
```

`kubectl edit` works too (set `type: ClusterIP` and remove the `nodePort` line). The API server clears the node port when the type changes.

## Question 2: least privilege for `jacob` (`dev-z`)

```bash
kubectl -n dev-z get rolebinding dev-user-binding -o wide      # Role dev-user-access
kubectl -n dev-z apply -f - <<'EOF'
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata: {name: dev-user-access, namespace: dev-z}
rules:
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["get", "list", "watch"]
- apiGroups: [""]
  resources: ["configmaps"]
  verbs: ["get", "list"]
EOF
kubectl auth can-i delete pods -n dev-z --as=jacob       # no
kubectl auth can-i get secrets -n dev-z --as=jacob       # no
```

## Question 3: kubelet of `{{NODE02}}`

```bash
ssh {{NODE02}}
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
```

```bash
systemctl restart kubelet
systemctl status kubelet
exit
kubectl get node {{NODE02}}
kubectl get --raw /api/v1/nodes/{{NODE02}}/proxy/configz | jq '.kubeletconfig | {a: .authentication.anonymous, z: .authorization.mode}'
```

If `--anonymous-auth` or `--authorization-mode` flags are in `/var/lib/kubelet/kubeadm-flags.env` they win over the file: check the effective values with `configz`.

## Question 4: SBOM of the image of a Pod

```bash
IMAGE=$(kubectl -n sbom-lab get pod kiwi -o jsonpath='{.spec.containers[0].image}')
cd /tmp/exam/mhagou-007-q4
trivy image --format spdx-json --output sbom.spdx.json "$IMAGE"
trivy image --format cyclonedx --output sbom.cdx.json "$IMAGE"
jq -r '.packages[] | select(.name == "openssl") | .versionInfo' sbom.spdx.json | tee openssl-version.txt
```

`bom` (kubernetes-sigs/bom) is not installed in this lab: `trivy image --format spdx-json|cyclonedx` creates the same documents. With an image archive: `trivy image --input image.tar --format spdx-json ...`.

## Question 5: Ingress with TLS and an HTTP to HTTPS redirect (Traefik, `rocket`)

```bash
cd /tmp/exam/mhagou-007-q5
kubectl -n rocket create secret tls secret-tls --cert=rocket.crt --key=rocket.key
kubectl apply -f - <<'EOF'
apiVersion: traefik.io/v1alpha1
kind: Middleware
metadata: {name: https-redirect, namespace: rocket}
spec:
  redirectScheme:
    scheme: https
    permanent: true
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: rocket-ingress
  namespace: rocket
  annotations:
    traefik.ingress.kubernetes.io/router.middlewares: rocket-https-redirect@kubernetescrd
spec:
  ingressClassName: traefik
  tls:
  - hosts: [rocket-server.local]
    secretName: secret-tls
  rules:
  - host: rocket-server.local
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: rocket-server
            port: {number: 80}
EOF
IP=$(kubectl -n traefik get svc traefik -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
curl -sI --resolve rocket-server.local:80:$IP http://rocket-server.local/ | head -3      # 301/308 -> https://
curl -sk --resolve rocket-server.local:443:$IP https://rocket-server.local/
```

The source used ingress-nginx (`nginx.ingress.kubernetes.io/ssl-redirect: "true"`); Traefik needs a `Middleware` (`redirectScheme`) referenced as `<namespace>-<name>@kubernetescrd` in the annotation `router.middlewares` (plural). A wrong annotation shows in `kubectl logs -n traefik deploy/traefik`, not in the Ingress events.

## Question 6: Docker-style daemon on `{{NODE01}}`

```bash
ssh {{NODE01}}
systemctl cat dockerd-lab.service        # ExecStart=... -H unix:///run/dockerd-lab.sock -H tcp://0.0.0.0:2375 --group=docker
systemctl edit --full dockerd-lab.service
```

Change the ExecStart line to:

```
ExecStart=/usr/local/bin/dockerd-lab -H unix:///run/dockerd-lab.sock --group=root
```

```bash
systemctl daemon-reload
systemctl restart dockerd-lab.service
ss -ltn | grep 2375          # nothing
stat -c %G /run/dockerd-lab.sock     # root
```

Alternative: keep the settings in `/etc/dockerd-lab/daemon.json` (`{"hosts": ["unix:///run/dockerd-lab.sock"], "group": "root"}`) and remove the `-H` / `--group` flags from the unit; with the same setting in both places the daemon refuses to start (as `dockerd` does): `journalctl -u dockerd-lab`.

## Question 7: ICMP redirects (`{{NODE02}}`)

```bash
ssh {{NODE02}}
sysctl -w net.ipv4.conf.default.accept_redirects=0 net.ipv4.conf.default.send_redirects=0
cat > /etc/sysctl.d/98-redirects.conf <<'EOF'
net.ipv4.conf.default.accept_redirects = 0
net.ipv4.conf.default.send_redirects = 0
EOF
sysctl --system | grep redirects
```

Editing `/etc/sysctl.conf` also works (it is read last). A file that sorts after yours and sets the values to 1 would win: `sysctl --system` shows the order. `sysctl -p` only reads `/etc/sysctl.conf`. (The source task disabled `net.ipv4.ip_forward`, which would break the pod network of a Kubernetes node.)

## Question 8: namespaces must carry the label `env` (ValidatingAdmissionPolicy)

```bash
kubectl apply -f - <<'EOF'
apiVersion: admissionregistration.k8s.io/v1
kind: ValidatingAdmissionPolicy
metadata:
  name: require-env-label
spec:
  failurePolicy: Fail
  matchConstraints:
    resourceRules:
    - apiGroups: [""]
      apiVersions: ["v1"]
      operations: ["CREATE"]
      resources: ["namespaces"]
  matchConditions:
  - name: lab-namespaces
    expression: "object.metadata.name.startsWith('lab-')"
  validations:
  - expression: "has(object.metadata.labels) && 'env' in object.metadata.labels"
    message: "namespaces named lab-* must have the label env"
---
apiVersion: admissionregistration.k8s.io/v1
kind: ValidatingAdmissionPolicyBinding
metadata:
  name: require-env-label-binding
spec:
  policyName: require-env-label
  validationActions: ["Deny"]
EOF
kubectl create namespace lab-bad                       # denied
kubectl create namespace lab-good --dry-run=client -o yaml | kubectl label --local -f - env=test -o yaml | kubectl apply -f -
```

The source used OPA Gatekeeper (ConstraintTemplate `K8sRequiredLabels`), which is not installed here; admission policies in CEL are built in. The policy is limited to `lab-*` so that other namespaces can still be created.

## Question 9: Falco rule for `/dev/mem`

```bash
ssh {{NODE01}}
vi /etc/falco/falco_rules.local.yaml
```

```yaml
- list: mem_file
  items: [/dev/mem]

- rule: devmem
  desc: A container tried to read /dev/mem
  condition: >
    fd.name in (mem_file) and container.id != host
  output: >
    Shell (container_id=%container.id)
  priority: NOTICE
```

```bash
falco -V /etc/falco/falco_rules.yaml -V /etc/falco/falco_rules.local.yaml     # validate
falco -r /etc/falco/falco_rules.yaml -r /etc/falco/falco_rules.local.yaml -M 30 &
kubectl exec -n devmem-lab test-falco -- cat /dev/mem        # No such file or directory, the alert is printed anyway
```

Falco evaluates the rules in file order (`rule_matching: first`), the default rules first: `-r` with only the local file works as well, but then the default macros are not available.

## Question 10: Cilium policies

```bash
kubectl apply -f - <<'EOF'
apiVersion: cilium.io/v2
kind: CiliumNetworkPolicy
metadata: {name: database, namespace: data-tier}
spec:
  endpointSelector: {}
  ingress:
  - fromEndpoints:
    - matchLabels:
        app: backend
        io.kubernetes.pod.namespace: web-tier
    toPorts:
    - ports:
      - {port: "3306", protocol: TCP}
  egress:
  - toEndpoints:
    - matchLabels:
        io.kubernetes.pod.namespace: kube-system
        k8s-app: kube-dns
    toPorts:
    - ports:
      - {port: "53", protocol: UDP}
      - {port: "53", protocol: TCP}
---
apiVersion: cilium.io/v2
kind: CiliumNetworkPolicy
metadata: {name: dev-api, namespace: dev-clients}
spec:
  endpointSelector:
    matchLabels: {env: dev}
  egress:
  - toEntities: [kube-apiserver]
EOF
```

The namespace label must be in the same `matchLabels` item (`io.kubernetes.pod.namespace`): a selector without it would also match `app=backend` Pods of other namespaces (`outside-lab`). Cilium allows an egress rule next to the NetworkPolicy `dev-initial-deny`: the allowed traffic is the union of the policies.

## Question 11: SHA-512 integrity

```bash
cd /tmp/exam/mhagou-007-q11
sha512sum -c reference.sha512            # bin/<name>: FAILED for the tampered files
rm bin/<the names that FAILED>
sha512sum -c reference.sha512 --ignore-missing
```

---

## Notes on the conversion

- Q1 keeps the source task (namespace `system-hardening` became `exposure-lab`).
- Q3: runs on `{{NODE02}}` (the source changed the control plane kubelet; restarting it would take the static Pods down).
- Q4: the source was a syntax exercise with an empty archive and nothing to validate; it now generates and reads real SBOMs with `trivy` (`bom` is not installed).
- Q5: ingress-nginx does not exist in this cluster: Traefik with a redirect middleware.
- Q6: the nodes have no Docker Engine (installing it changes iptables rules, a risk for Cilium): a small daemon with the same configuration model replaces it.
- Q7: the source disabled `net.ipv4.ip_forward`, which would break pod networking; the redirect parameters are used instead.
- Q8: OPA Gatekeeper is not installed: ValidatingAdmissionPolicy; limited to `lab-*` namespaces.
- Q9: the pod runs on `{{NODE01}}` in its own namespace (the source used `default` on the control plane).
- Q10: namespaces renamed (`default` is not used), stage 1 and stage 2 of the source are merged in the final policy.
- Q11: the source compared the real kubelet binary with a reference created at setup (nothing could ever mismatch); now there are tampered copies to find.
