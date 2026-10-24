# CKS - MHagou - Exam 8 - Answer key

Adapted from the "exam-8" labs of the MHagou CKS repository. Every command below was run against the lab cluster (kubeadm, `{{CONTROL_PLANE}}`, `{{NODE01}}`, `{{NODE02}}`; Traefik as ingress controller). Differences from the source labs: namespaces are exclusive to each question, the nginx ingress class was replaced by Traefik, the files live under `/tmp/exam/mhagou-008-qN/`, and the lab nodes are `{{NODE01}}` / `{{NODE02}}`.

---

## Question 1: Falco rule for a rogue container (`forensics-lab`)

`-r` replaces the configured rule files, so a rule written for `falco -r catch-rogue.yaml` must use raw conditions (no default macros):

```bash
cat > /tmp/exam/mhagou-008-q1/catch-rogue.yaml <<'EOF'
- rule: Catch Sensitive File Access
  desc: A process inside a container reads secret.txt
  condition: evt.type in (open, openat, openat2) and evt.dir=< and fd.name endswith secret.txt and container.id != host
  output: "BINGO container=%container.name id=%container.id file=%fd.name cmd=%proc.cmdline"
  priority: WARNING
EOF
scp /tmp/exam/mhagou-008-q1/catch-rogue.yaml {{NODE01}}:/tmp/
ssh {{NODE01}} 'falco -r /tmp/catch-rogue.yaml -M 15'
```

(The source answer `fd.name contains "secret.txt" and container.id != "host"` works too; a rule that uses the macros `open_read` / `container` also works when the default rules are loaded first.)

Pitfalls:
- Without `container.id != host` the read of the same file made on the node triggers the rule.
- The alert must show the container (id or name), the path of the file and the command: put `%container.id` / `%container.name`, `%fd.name` and `%proc.cmdline` in the output.
- Do not modify or restart `rogue-pod`.

## Question 2: Ingress with TLS and HTTPS redirect, Traefik (`secure-web`)

```bash
kubectl apply -f - <<'EOF'
apiVersion: traefik.io/v1alpha1
kind: Middleware
metadata: {name: https-redirect, namespace: secure-web}
spec:
  redirectScheme: {scheme: https, permanent: true}
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: secure-ingress
  namespace: secure-web
  annotations:
    traefik.ingress.kubernetes.io/router.middlewares: secure-web-https-redirect@kubernetescrd
spec:
  ingressClassName: traefik
  tls:
  - hosts: [secure-app.company.com]
    secretName: web-tls
  rules:
  - host: secure-app.company.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: secure-app
            port: {number: 80}
EOF
IP=$(kubectl get svc -n traefik traefik -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
curl -sI --resolve secure-app.company.com:80:$IP http://secure-app.company.com/          # 301 -> https://...
curl -sk --resolve secure-app.company.com:443:$IP https://secure-app.company.com/        # MHagou secure-app
```

With ingress-nginx an Ingress with a `tls` section already redirects (`nginx.ingress.kubernetes.io/ssl-redirect: "true"`); with Traefik the redirect needs a `Middleware`. The Traefik problems show in `kubectl logs -n traefik deploy/traefik` (not in `kubectl describe ingress`).

### Traefik middleware cheat sheet

The annotation value is `<namespace>-<middleware-name>@kubernetescrd` (key `router.middlewares`, plural, comma separated for a chain). It applies to the whole Ingress.

| Need | Middleware `spec` |
|---|---|
| HTTP to HTTPS | `redirectScheme: {scheme: https, permanent: true}` |
| Redirect by regex | `redirectRegex: {regex: "^https?://[^/]+/old/(.*)", replacement: "/new/${1}", permanent: true}` |
| Remove a path prefix | `stripPrefix: {prefixes: ["/app"]}` |
| Headers / auth / limits | `headers`, `basicAuth`, `ipAllowList`, `rateLimit` |

## Question 3: egress NetworkPolicy with IP blocks (`threat-prevention`)

```bash
kubectl apply -f - <<'EOF'
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: block-malicious-egress
  namespace: threat-prevention
spec:
  podSelector: {}
  policyTypes: [Egress]
  egress:
  - ports:                       # DNS to any destination, malicious ranges included
    - {port: 53, protocol: UDP}
    - {port: 53, protocol: TCP}
  - to:                          # everything else except the malicious ranges
    - ipBlock:
        cidr: 0.0.0.0/0
        except: [192.168.100.0/24, 10.0.99.0/24]
EOF
```

Pitfalls: `policyTypes` must not include `Ingress`; an extra rule such as `- {}` re-opens the blocked ranges; limiting DNS to `kube-dns` removes the DNS exception for the malicious ranges.

Note for this lab (Cilium): an `ipBlock` rule only matches addresses outside the cluster, never the IP of a Pod, so with this policy the Pods can still resolve DNS (rule without `to`) but cannot reach each other: the validator therefore only checks DNS at runtime and evaluates the `ipBlock` rules for sample external addresses.

## Question 4: RBAC privilege escalation (`ci-cd`)

`ci-bot-role` lets `ci-bot` create/update/patch/delete (Cluster)RoleBindings and use the `bind` verb on roles and clusterroles: that is the escalation path. Keep the workload permissions and the read-only access to the bindings:

```bash
kubectl apply -f - <<'EOF'
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata: {name: ci-bot-role}
rules:
- {apiGroups: [""], resources: [pods, services, configmaps], verbs: [get, list, watch, create, update, delete]}
- {apiGroups: [apps], resources: [deployments, replicasets], verbs: [get, list, watch, create, update, delete]}
- {apiGroups: [rbac.authorization.k8s.io], resources: [clusterrolebindings, rolebindings], verbs: [get, list, watch]}
EOF
kubectl auth can-i create clusterrolebindings --as=system:serviceaccount:ci-cd:ci-bot            # no
kubectl create rolebinding x --clusterrole=admin --serviceaccount=ci-cd:ci-bot -n ci-cd \
  --as=system:serviceaccount:ci-cd:ci-bot --dry-run=server                                          # forbidden
```

Removing only the `bind` verb is also enough to stop the escalation to `admin`/`cluster-admin` (the account does not hold their permissions). Deleting the ClusterRoleBinding closes the hole too but removes the permissions that had to be kept.

## Question 5: hardened Dockerfile (files)

```dockerfile
FROM gcr.io/distroless/base
COPY ./app-server /app/server
USER nonroot:nonroot
ENTRYPOINT ["/app/server"]
```

The distroless image has no shell: the `RUN` instructions (package installation, `chmod`, `useradd`) cannot stay, and the shell form of `ENTRYPOINT` needs `/bin/sh`.

## Question 6: seccomp profile that blocks ptrace (`secure-runtime`)

```bash
ssh {{NODE01}}
mkdir -p /var/lib/kubelet/seccomp/profiles
cat > /var/lib/kubelet/seccomp/profiles/block-debug.json <<'EOF'
{
  "defaultAction": "SCMP_ACT_ALLOW",
  "syscalls": [
    {"names": ["ptrace", "process_vm_readv"], "action": "SCMP_ACT_ERRNO"}
  ]
}
EOF
exit
kubectl get pod secure-app -n secure-runtime -o yaml > /tmp/pod.yaml     # edit: remove status/uid..., set the profile
kubectl delete pod secure-app -n secure-runtime
kubectl apply -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata: {name: secure-app, namespace: secure-runtime}
spec:
  nodeName: {{NODE01}}
  securityContext:
    seccompProfile: {type: Localhost, localhostProfile: profiles/block-debug.json}
  containers:
  - name: nginx-container
    image: nginx:1.27-alpine
    ports: [{containerPort: 80}]
EOF
kubectl exec -n secure-runtime secure-app -- grep Seccomp /proc/1/status     # Seccomp: 2
```

The action is `SCMP_ACT_ERRNO` (the question's `SNMP_ACT_ERRNO` is a typo). The profile path is relative to `/var/lib/kubelet/seccomp`. A seccomp profile of a Pod cannot be changed in place: delete and re-create it on the same node, or it will not find the file.
