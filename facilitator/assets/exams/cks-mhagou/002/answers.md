# CKS - MHagou - Exam 2 - Answer key

Commands were run against the lab cluster (kubeadm, three nodes: `{{CONTROL_PLANE}}`, `{{NODE01}}`, `{{NODE02}}`).
The namespaces, files and names are the ones used by the questions. Based on the labs of
`mhagou/exam-2` (solutions corrected and adapted to this cluster).

---

## Question 1: Trivy (`spectacle`)

```bash
kubectl -n spectacle get pods -o custom-columns=POD:.metadata.name,IMAGE:.spec.containers[*].image
for i in nginx:1.16 httpd:2.4.49 redis:7.2-alpine busybox:1.36.1; do
  echo "== $i"; trivy image -q --severity CRITICAL $i | tail -4
done
kubectl -n spectacle delete pod atlas beacon          # nginx:1.16 and httpd:2.4.49 have CRITICAL findings
```

`redis:7.2-alpine` has HIGH findings only (no CRITICAL) and `busybox:1.36.1` none: keep both.
(The counts are those of the Trivy database when the exam was written; the validators use the Pod names.)

## Question 2: RBAC (`seminar`)

```bash
kubectl -n seminar create serviceaccount seminar-sa
kubectl -n seminar create role k8s-seminar --verb=create,update --resource=pods,deployments
kubectl -n seminar create rolebinding k8s-seminar-bind --role=k8s-seminar --serviceaccount=seminar:seminar-sa
kubectl auth can-i create deployments.apps -n seminar --as=system:serviceaccount:seminar:seminar-sa   # yes
kubectl auth can-i delete pods -n seminar --as=system:serviceaccount:seminar:seminar-sa                # no
```

## Question 3: AppArmor (`apparmor-lab`)

```bash
ssh {{NODE01}}
cat /etc/apparmor.d/spectacleapp
apparmor_parser -q -r /etc/apparmor.d/spectacleapp
aa-status | grep spectacleapp
exit
kubectl -n apparmor-lab create serviceaccount test-sa
kubectl -n apparmor-lab get pod apparmor-pod -o yaml > /tmp/pod.yaml    # edit it, then delete and re-create the Pod
```

```yaml
apiVersion: v1
kind: Pod
metadata: {name: apparmor-pod, namespace: apparmor-lab, labels: {run: nginx}}
spec:
  nodeName: {{NODE01}}
  serviceAccountName: test-sa
  containers:
  - name: nginx
    image: nginx:alpine
    securityContext:
      appArmorProfile: {type: Localhost, localhostProfile: spectacleapp}   # privileged: true removed
    volumeMounts: [{name: records, mountPath: /data/records, readOnly: true}]
  volumes: [{name: records, configMap: {name: records}}]
```

```bash
kubectl delete pod apparmor-pod -n apparmor-lab --now && kubectl apply -f /tmp/pod.yaml
kubectl -n apparmor-lab exec apparmor-pod -- cat /data/records/read-test     # Permission denied
```

The profile must be loaded on the node that runs the Pod; the annotation form (`container.apparmor.security.beta.kubernetes.io/nginx: localhost/spectacleapp`) works as well.

## Question 4: Secret (`secret-lab`)

```bash
kubectl -n secret-lab create secret generic secret1 --from-literal=user=admin --from-literal=pass=P455W0RD
kubectl apply -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata: {name: secretpod, namespace: secret-lab}
spec:
  containers:
  - name: secretpod
    image: nginx
    volumeMounts: [{name: vol1, mountPath: /etc/foo, readOnly: true}]
  volumes: [{name: vol1, secret: {secretName: secret1}}]
EOF
```

## Question 5: seccomp (`alpha`)

```bash
ssh {{NODE01}} 'mkdir -p /var/lib/kubelet/seccomp/profiles'
scp /tmp/exam/mhagou-002-q5/auditing.json {{NODE01}}:/var/lib/kubelet/seccomp/profiles/auditing.json
kubectl apply -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata: {name: nginx-auditing, namespace: alpha}
spec:
  nodeName: {{NODE01}}
  securityContext:
    seccompProfile: {type: Localhost, localhostProfile: profiles/auditing.json}   # relative to /var/lib/kubelet/seccomp
  containers: [{name: nginx, image: nginx}]
EOF
kubectl -n alpha exec nginx-auditing -- grep Seccomp /proc/1/status      # Seccomp: 2
```

`SCMP_ACT_LOG` allows every syscall and logs it, so the Pod runs normally but is filtered (`Seccomp: 2`).
The pod needs `nodeName: {{NODE01}}` (or a nodeSelector): the profile exists on that node only. Without the file the Pod stays in `CreateContainerError`.

## Question 6: RuntimeClass (`sandbox-test`)

```bash
kubectl apply -f - <<'EOF'
apiVersion: node.k8s.io/v1
kind: RuntimeClass
metadata: {name: runsc-class}
handler: runsc
---
apiVersion: v1
kind: Pod
metadata: {name: gvisor-pod, namespace: sandbox-test}
spec:
  runtimeClassName: runsc-class
  containers: [{name: gvisor-pod, image: nginx}]
EOF
kubectl -n sandbox-test exec gvisor-pod -- dmesg | head -3        # Starting gVisor...
```

## Question 7: kube-bench, kubelet of `{{NODE01}}`

```bash
ssh {{NODE01}}
vi /var/lib/kubelet/config.yaml
```

```yaml
authorization:
  mode: Webhook            # was AlwaysAllow
protectKernelDefaults: true  # was false
readOnlyPort: 0            # was 10255 (or delete the line)
```

```bash
systemctl restart kubelet && systemctl is-active kubelet
exit
kubectl get node {{NODE01}}
kubectl get --raw /api/v1/nodes/{{NODE01}}/proxy/configz | jq '.kubeletconfig | {authorization, protectKernelDefaults, readOnlyPort}'
```

`protectKernelDefaults: true` makes the kubelet refuse to start when the kernel parameters differ from its expectations: they are set on the nodes of this lab.

## Question 8: audit policy (`test`)

```bash
ssh {{CONTROL_PLANE}}
cat > /etc/kubernetes/test-audit.yaml <<'EOF'
apiVersion: audit.k8s.io/v1
kind: Policy
omitStages: ["RequestReceived"]
rules:
- level: Metadata
  verbs: ["delete", "update"]
  namespaces: ["test"]
  resources:
  - group: ""
    resources: ["pods"]
- level: None
EOF
vi /etc/kubernetes/manifests/kube-apiserver.yaml
```

```yaml
    - --audit-policy-file=/etc/kubernetes/test-audit.yaml
    - --audit-log-path=/var/log/test-audit.log
    - --audit-log-maxage=20
    ...
    volumeMounts:
    - {name: audit, mountPath: /etc/kubernetes/test-audit.yaml, readOnly: true}
    - {name: audit-log, mountPath: /var/log/test-audit.log}
  volumes:
  - name: audit
    hostPath: {path: /etc/kubernetes/test-audit.yaml, type: File}
  - name: audit-log
    hostPath: {path: /var/log/test-audit.log, type: FileOrCreate}
```

Wait for the API server (`crictl ps`, `kubectl get nodes`). Rules are evaluated in order and the first match decides; a request that matches no rule is not logged, so the final `level: None` is optional. Mounting the log directory (`/var/log`) instead of the file also works (and keeps log rotation possible).

## Question 9: Falco output (`space`)

```bash
ssh {{NODE02}}
grep -n "rule: Terminal shell in container" /etc/falco/falco_rules.yaml
vi /etc/falco/falco_rules.local.yaml
```

Copy the rule (same name) into the local file and change the output (quote it: an unquoted value that contains `: ` or `|` is invalid YAML and Falco does not start):

```yaml
- rule: Terminal shell in container
  desc: A shell was used as the entrypoint/exec point into a container with an attached terminal.
  condition: >
    spawned_process and container and shell_procs and proc.tty != 0
    and container_entrypoint and not user_expected_terminal_shell_in_container_conditions
  output: "%evt.time.iso8601,%user.uid,%container.id,%container.image.repository"
  priority: NOTICE
  tags: [maturity_stable, container, shell, mitre_execution, T1059]
```

```bash
systemctl restart falco-modern-bpf && systemctl is-active falco-modern-bpf
exit
kubectl -n space exec -it worker-pod -- sh -c 'true'
ssh {{NODE02}} 'journalctl -u falco-modern-bpf --since "-1 min" --no-pager | tail -3'
```

Editing the rule in place in `/etc/falco/falco_rules.yaml` works too. A NEW rule with a different name does not help: Falco evaluates the rules with `rule_matching: first`, and the default rule matches the event first. Falco also appends the container fields (`container_id=...`) to every alert: they do not replace the requested format.

## Question 10: ImagePolicyWebhook

```bash
ssh {{CONTROL_PLANE}}
cat /etc/kubernetes/pki/admission_configuration.yaml
ls /etc/kubernetes/pki/admission*
```

Two mistakes: `kubeConfigFile` points to `admission_kube_config.yml` (the file is `.yaml`) and `defaultAllow` is `true`.

```bash
sed -i 's#admission_kube_config.yml#admission_kube_config.yaml#; s#defaultAllow: true#defaultAllow: false#' /etc/kubernetes/pki/admission_configuration.yaml
vi /etc/kubernetes/manifests/kube-apiserver.yaml
```

```yaml
    - --enable-admission-plugins=NodeRestriction,ImagePolicyWebhook
    - --admission-control-config-file=/etc/kubernetes/pki/admission_configuration.yaml
```

`/etc/kubernetes/pki` is already mounted into the kube-apiserver Pod (volume `k8s-certs`), so the two files need no extra volume (adding `hostPath` mounts for the files, as in the source, is harmless). Wait for the API server, then:

```bash
kubectl run t --image=untrusted.example.com/app:1.0 -n image-review --dry-run=server   # denied by the image policy webhook
kubectl run t --image=nginx -n image-review --dry-run=server                           # accepted
```

If the API server never becomes ready: `crictl ps -a`, `crictl logs <apiserver container>` shows the plugin error (a `kubeConfigFile` that does not exist makes it exit). With `defaultAllow: false` and a wrong backend URL every Pod creation is denied.

## Question 11: admission policy instead of PodSecurityPolicy (`policy-lab`)

```bash
kubectl apply -f - <<'EOF'
apiVersion: admissionregistration.k8s.io/v1
kind: ValidatingAdmissionPolicy
metadata: {name: pod-psp}
spec:
  failurePolicy: Fail
  matchConstraints:
    resourceRules:
    - {apiGroups: [""], apiVersions: ["v1"], operations: ["CREATE", "UPDATE"], resources: ["pods"]}
  validations:
  - expression: "(!has(object.spec.containers) || object.spec.containers.all(c, !has(c.securityContext) || !has(c.securityContext.privileged) || !c.securityContext.privileged)) && (!has(object.spec.initContainers) || object.spec.initContainers.all(c, !has(c.securityContext) || !has(c.securityContext.privileged) || !c.securityContext.privileged))"
    message: "privileged containers are not allowed"
  - expression: "!has(object.spec.volumes) || object.spec.volumes.all(v, has(v.secret) || has(v.configMap) || has(v.projected))"
    message: "only secret and configMap volumes are allowed"
---
apiVersion: admissionregistration.k8s.io/v1
kind: ValidatingAdmissionPolicyBinding
metadata: {name: pod-psp-binding}
spec:
  policyName: pod-psp
  validationActions: ["Deny"]
  matchResources:
    namespaceSelector:
      matchLabels: {kubernetes.io/metadata.name: policy-lab}
EOF
```

The `projected` type must be allowed (the service account token volume is injected into every Pod). runAsUser, fsGroup, seLinux and supplemental groups are simply not mentioned: "RunAsAny" means no restriction. Test with `kubectl run ... --dry-run=server -n policy-lab` and a Pod spec with a `hostPath` or `privileged: true`.

## Question 12: NetworkPolicy (`moon`)

```bash
kubectl get ns hello --show-labels            # ns=test
kubectl apply -f - <<'EOF'
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata: {name: np-restriction, namespace: moon}
spec:
  podSelector: {matchLabels: {run: nginx-pod}}
  policyTypes: [Ingress]
  ingress:
  - from:
    - namespaceSelector: {matchLabels: {ns: test}}
    - namespaceSelector: {}            # same item: AND, i.e. app=backend in ANY namespace
      podSelector: {matchLabels: {app: backend}}
    ports: [{protocol: TCP, port: 80}]
EOF
```

A `podSelector` alone selects the Pods of the policy's own namespace only: `namespaceSelector: {}` in the same list item is what makes the label match in any namespace. The Pods of `moon` itself are not in the list, so they are denied too.

## Question 13: deny all (`lockdown`)

```bash
kubectl apply -f - <<'EOF'
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata: {name: all-deny, namespace: lockdown}
spec:
  podSelector: {}
  policyTypes: [Ingress, Egress]
EOF
```

With the Egress type and no rules even DNS is denied.

## Question 14: Dockerfile

```dockerfile
FROM ubuntu:24.04

ENV CI=true

RUN apt-get update && \
    apt-get install -y --no-install-recommends wget curl && \
    rm -rf /var/lib/apt/lists/*

USER nobody

WORKDIR /code
COPY package.json package-lock.json /code/
RUN npm ci
COPY src /code/src

CMD [ "npm", "start" ]
```

A pinned tag (or a digest) instead of `latest`; update and install in one layer (a cached `apt-get update` layer gives outdated packages); the last `USER` is not root.

---

## Differences from the source labs (`mhagou/exam-2`)

- Q3, Q4, Q6, Q8, Q11 use their own namespaces (the source reused `spectacle` and `seminar`; `test` is used by Q8 only); the RuntimeClass of Q6 is named `runsc-class` because the cluster already has `gvisor`.
- Q5: the source solution also enables `seccompDefault` in the kubelet: not needed and not part of the question. The profile is provided in `/tmp/exam/mhagou-002-q5/`.
- Q7: three findings are seeded (authorization mode, kernel defaults, read-only port); the source only mentions two as examples.
- Q9: the lab empties the local rules file of {{NODE02}} so that no older local rule can match the event first (Falco `rule_matching: first`), and the requested output format differs from the default one of the rule (the default output has no comma-separated time/uid/container/image prefix).
- Q10: the webhook backend runs (the source leaves it unavailable, which would deny every Pod of the cluster after the question is solved); it only denies one registry so that the other questions keep working.
- Q11: PodSecurityPolicy is replaced by a ValidatingAdmissionPolicy (the source says "Resources removed: PSS instead").
- Q12/Q13: Q13 names the namespace (`lockdown`), which the source left out (it would have used `default`).
