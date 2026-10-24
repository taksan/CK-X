# CKS Practice Lab 4 - Answer key

Commands were designed against the lab cluster (kubeadm, three nodes: `{{CONTROL_PLANE}}`, `{{NODE01}}`, `{{NODE02}}`).
Some questions deliberately differ from the exercise they are based on (see the notes at the end).

---

## Question 1: Cilium policies (`team-dev`)

```bash
kubectl apply -f - <<'EOF'
apiVersion: cilium.io/v2
kind: CiliumNetworkPolicy
metadata: {name: team-dev, namespace: team-dev}
spec:
  endpointSelector: {matchLabels: {role: backend}}
  ingressDeny:
  - fromEndpoints: [{matchLabels: {role: stuff}}]
    icmps: [{fields: [{type: 8, family: IPv4}]}]
---
apiVersion: cilium.io/v2
kind: CiliumNetworkPolicy
metadata: {name: team-dev-2, namespace: team-dev}
spec:
  endpointSelector: {matchLabels: {role: database}}
  egress:
  - toEndpoints: [{matchLabels: {role: api-service}}]
    authentication: {mode: required}
EOF
```

A deny rule on the ingress of `backend-0` for the `stuff` Pods and ICMP echo requests only (type 8) keeps TCP and the other Pods working.

## Question 2: seccomp (`secure-app`)

```bash
ssh {{NODE01}}
sudo mkdir -p /var/lib/kubelet/seccomp/profiles
sudo tee /var/lib/kubelet/seccomp/profiles/no-mkdir.json <<'EOF'
{"defaultAction":"SCMP_ACT_ALLOW","syscalls":[{"names":["mkdir","mkdirat"],"action":"SCMP_ACT_ERRNO"}]}
EOF
exit
kubectl -n secure-app patch deployment webapp --type merge -p '{"spec":{"template":{"spec":{"securityContext":{"seccompProfile":{"type":"Localhost","localhostProfile":"profiles/no-mkdir.json"}}}}}}'
kubectl -n secure-app rollout status deployment webapp
kubectl -n secure-app exec deploy/webapp -- mkdir /tmp/x     # fails
```

## Question 3: workloads sharing the node (`ci-cd`)

`builder` uses `hostPID`, `hostIPC`, `hostNetwork` and a `hostPath` volume:

```bash
kubectl -n ci-cd get deploy -o yaml | grep -E 'host(PID|IPC|Network)|hostPath' -B2
kubectl -n ci-cd edit deployment builder     # remove hostPID/hostIPC/hostNetwork, the hostPath volume and its volumeMount
kubectl -n ci-cd rollout status deployment builder
```

## Question 4: Trivy (`scan-lab`)

```bash
kubectl -n scan-lab get pods,deploy -o jsonpath='{range .items[*]}{.metadata.name}{" "}{..image}{"\n"}{end}'
for i in nginx:1.16 httpd:2.4.49 busybox:1.36.1 alpine:3.20; do echo $i; trivy image -q --severity HIGH,CRITICAL $i | tail -3; done
kubectl -n scan-lab delete deployment storefront
kubectl -n scan-lab delete pod reports
```

## Question 5: default-deny egress (`egress-lab`)

```bash
kubectl apply -f - <<'EOF'
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata: {name: default-deny, namespace: egress-lab}
spec:
  podSelector: {}
  policyTypes: [Egress]
  egress:
  - to:
    - namespaceSelector: {matchLabels: {kubernetes.io/metadata.name: kube-system}}
      podSelector: {matchLabels: {k8s-app: kube-dns}}
    ports:
    - {protocol: UDP, port: 53}
    - {protocol: TCP, port: 53}
EOF
```

## Question 6: ServiceAccount without Secret access (`qa`)

The RoleBinding `all-service-accounts` binds the group `system:serviceaccounts:qa` to the Role `shared-reader` (ConfigMaps and Secrets). Split the Role so that Secrets are no longer granted to everyone:

```bash
kubectl -n qa create sa backend-qa
kubectl -n qa patch role shared-reader --type json -p '[{"op":"remove","path":"/rules/1"}]'   # drop the secrets rule
# (an extra Role that only reads pods does NOT help: the secrets rule is still granted to the group)
sed -i 's/^spec:/spec:\n  serviceAccountName: backend-qa/' /tmp/exam/cks-004-q6/frontend-pod.yaml
kubectl -n qa delete pod frontend --now && kubectl apply -f /tmp/exam/cks-004-q6/frontend-pod.yaml
```

## Question 7: Falco on one Pod (`monitoring-lab`)

```bash
ssh {{NODE01}}
sudo mkdir -p /tmp/exam/cks-004-q7
cat > /tmp/exam/cks-004-q7/rules.yaml <<'EOF'
- rule: tomcat process
  desc: processes spawned in the Pod tomcat
  condition: evt.type = execve and evt.dir = < and k8s.pod.name = tomcat
  output: "[%evt.time.iso8601],[%user.uid],[%proc.name]"
  priority: WARNING
EOF
sudo timeout 50 falco -r /tmp/exam/cks-004-q7/rules.yaml -o json_output=false -o stdout_output.enabled=true 2>/dev/null \
  | grep -oE '\[[^]]*\],\[[^]]*\],\[[^]]*\]' > /tmp/exam/cks-004-q7/report
```

(Any Falco rule file/format works as long as the lines match the format. `-r` replaces the default rules, so a custom rule file must not depend on the default macros. The Pod `tomcat` spawns `whoami` and the Pod `batch` spawns `hostname`.)

## Question 8: audit policy (`frontend`)

On `{{CONTROL_PLANE}}`, insert the new rules **before** the first rule of the base policy (the final `level: None` catch-all would swallow rules placed after it):

```yaml
apiVersion: audit.k8s.io/v1
kind: Policy
rules:
  - level: RequestResponse
    resources:
      - group: ""
        resources: ["nodes"]
  - level: Request
    namespaces: ["frontend"]
    resources:
      - group: ""
        resources: ["persistentvolumeclaims"]
  # ... the three original rules, unchanged ...
```

kube-apiserver manifest (`/etc/kubernetes/manifests/kube-apiserver.yaml`):

```
--audit-policy-file=/etc/audit/audit-policy.yaml
--audit-log-path=/var/log/kubernetes-logs.log
--audit-log-maxage=5
--audit-log-maxbackup=10
```

with `/etc/audit` mounted (a directory mount, not a single file) and `/var/log` mounted (the log directory). Wait for the API server to come back.

## Question 9: Secrets (`dev`, `app`)

```bash
kubectl -n dev get secret platform-certs -o jsonpath='{.data.ca\.crt}' | base64 -d > /tmp/exam/cks-004-q9/ca.crt
kubectl -n app create secret generic app-config-secret --from-literal=APP_USER=appadmin --from-literal=APP_PASS=Sup3rS3cret
kubectl apply -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata: {name: app-pod, namespace: app}
spec:
  containers:
  - name: nginx
    image: nginx
    volumeMounts: [{name: cfg, mountPath: /etc/app-config, readOnly: true}]
  volumes:
  - name: cfg
    secret: {secretName: app-config-secret, defaultMode: 0400}
EOF
```

## Question 10: Dockerfile and Deployment

Dockerfile: pin the base image (`FROM ubuntu:24.04`) and make the last `USER` instruction unprivileged: `USER reportuser` (the user the Dockerfile already creates), `USER nobody` or `65535` are all accepted; only root is rejected. A digest pin is accepted too (`ubuntu@sha256:...` or `ubuntu:latest@sha256:...`); `latest` alone is not. Deployment: `privileged: false` and `runAsUser: 65535`. Nothing is added or removed.

## Question 11: ServiceAccounts (`web-team`)

```bash
kubectl -n web-team create sa frontend-sa
kubectl -n web-team patch sa frontend-sa -p '{"automountServiceAccountToken": false}'
sed -i 's/serviceAccountName: frontend-svc/serviceAccountName: frontend-sa/' /tmp/exam/cks-004-q11/pod-manifest.yaml
kubectl apply -f /tmp/exam/cks-004-q11/pod-manifest.yaml
kubectl -n web-team get pods -o custom-columns=POD:.metadata.name,SA:.spec.serviceAccountName
kubectl -n web-team delete sa stale-account old-bot      # not used by any Pod; keep default, reporter-sa and frontend-sa
```

## Question 12: ValidatingAdmissionPolicy (`volume-lab`)

```bash
kubectl apply -f - <<'EOF'
apiVersion: admissionregistration.k8s.io/v1
kind: ValidatingAdmissionPolicy
metadata: {name: prevent-volume-policy}
spec:
  failurePolicy: Fail
  matchConstraints:
    resourceRules:
    - apiGroups: [""]
      apiVersions: ["v1"]
      operations: ["CREATE", "UPDATE"]
      resources: ["pods"]
  validations:
  - expression: "!has(object.spec.volumes) || object.spec.volumes.all(v, has(v.persistentVolumeClaim) || has(v.projected))"
    message: "only persistentVolumeClaim volumes are allowed"
---
apiVersion: admissionregistration.k8s.io/v1
kind: ValidatingAdmissionPolicyBinding
metadata: {name: prevent-volume-binding}
spec:
  policyName: prevent-volume-policy
  validationActions: ["Deny"]
  matchResources:
    namespaceSelector:
      matchLabels: {kubernetes.io/metadata.name: volume-lab}
EOF
```

(PodSecurityPolicy was removed in Kubernetes 1.25; ValidatingAdmissionPolicy is the current mechanism.)

## Question 13: SBOMs

```bash
cd /tmp/exam/cks-004-q13
trivy image --format spdx-json --output sbom1.json registry.k8s.io/pause:3.9
trivy image --format cyclonedx --output sbom2.json alpine:3.20
trivy sbom --severity HIGH,CRITICAL --format json --output sbom_result.json sbom_check.json
```

## Question 14: RBAC (`database`)

```bash
kubectl -n database get rolebinding -o wide | grep web-sa           # web-access-bind -> Role web-access
kubectl -n database patch role web-access --type merge -p '{"rules":[{"apiGroups":[""],"resources":["pods"],"verbs":["get"]}]}'
kubectl -n database create role web-sts-updater --verb=update --resource=statefulsets.apps
kubectl -n database create rolebinding web-sts-updater-bind --role=web-sts-updater --serviceaccount=database:web-sa
```

## Question 15: binary integrity

```bash
cd /tmp/exam/cks-004-q15/binaries
sha512sum -c ../checksums.sha512                                         # FAILED lines are the tampered binaries
rm <the binaries that do not match>
```

## Question 16: Pod Security Admission (`team-blue`)

```bash
kubectl label ns team-blue pod-security.kubernetes.io/enforce=restricted
kubectl -n team-blue delete pod -l app=privileged-runner
kubectl -n team-blue describe rs | grep FailedCreate > /tmp/exam/cks-004-q16/logs   # or: kubectl get events --field-selector reason=FailedCreate
cat /tmp/exam/cks-004-q16/logs
```

---

## Deviations from the source exercise

- Q2: a profile that denies `mkdir` replaces the 4-syscall allow list (not runnable by any real container); busybox replaces nginx.
- Q3: `docker.sock` permission changes replaced by removing host namespaces and host paths.
- Q12: PodSecurityPolicy replaced by ValidatingAdmissionPolicy.
- Q13: both formats generated with `trivy` (`bom` is not required).
- Q15: hashes of the question are checked against fixed content; the two tampered files are random.
