# CKS - MHagou - Exam 4 - Answer key

Based on the exercises of the MHagou labs (exam-4). Every command below was run against the lab
cluster (kubeadm, three nodes: `{{CONTROL_PLANE}}`, `{{NODE01}}`, `{{NODE02}}`).

---

## Question 1: ServiceAccount without token mount (`secret-room`)

```bash
kubectl create serviceaccount hidden-user -n secret-room
kubectl patch serviceaccount hidden-user -n secret-room -p '{"automountServiceAccountToken": false}'
# or: kubectl apply -f - with automountServiceAccountToken: false at the top level of the ServiceAccount

kubectl apply -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata: {name: nginx, namespace: secret-room}
spec:
  serviceAccountName: hidden-user
  containers:
  - {name: nginx, image: nginx}
EOF
kubectl exec -n secret-room nginx -- ls /var/run/secrets/kubernetes.io      # no such directory
```

The setting must be on the ServiceAccount (the Pod can also set `automountServiceAccountToken`, but a Pod that sets it to `true` overrides the ServiceAccount).

## Question 2: AppArmor (`write-guard`)

```bash
ssh {{NODE01}}
cat /etc/apparmor.d/deny-tmp-write
apparmor_parser -q /etc/apparmor.d/deny-tmp-write
grep k8s-deny-write /sys/kernel/security/apparmor/profiles     # loaded
exit
```

In `/tmp/exam/mhagou-004-q2/pod.yaml` reference the profile (Kubernetes 1.30+; it can be set on the container or on the Pod):

```yaml
spec:
  nodeName: {{NODE01}}
  containers:
  - name: hello
    image: busybox:1.36.1
    command: ["sh", "-c", "echo 'Hello AppArmor!' && sleep 3600"]
    securityContext:
      appArmorProfile:
        type: Localhost
        localhostProfile: k8s-deny-write
```

```bash
kubectl apply -f /tmp/exam/mhagou-004-q2/pod.yaml
kubectl exec -n write-guard hello-apparmor -- touch /tmp/x            # Permission denied
kubectl exec -n write-guard hello-apparmor -- touch /var/x            # works
```

If the profile is not loaded the Pod stays in `CreateContainerError`.

## Question 3: seccomp profile that logs `mkdir` (`syscall-lab`)

```bash
ssh {{NODE02}}
mkdir -p /var/lib/kubelet/seccomp
cat > /var/lib/kubelet/seccomp/audit.json <<'EOF'
{
  "defaultAction": "SCMP_ACT_ALLOW",
  "syscalls": [
    {"names": ["mkdir", "mkdirat"], "action": "SCMP_ACT_LOG"}
  ]
}
EOF
exit
```

The path of `localhostProfile` is relative to `/var/lib/kubelet/seccomp`. The Pod spec cannot be changed in place: delete and re-create it from the manifest.

```yaml
spec:
  nodeName: {{NODE02}}
  securityContext:
    seccompProfile:
      type: Localhost
      localhostProfile: audit.json
```

```bash
kubectl delete pod audit-pod -n syscall-lab --now
kubectl apply -f /tmp/exam/mhagou-004-q3/pod.yaml
kubectl exec -n syscall-lab audit-pod -- mkdir /tmp/test-trigger
ssh {{NODE02}} 'journalctl -k --since "-2 min" | grep "type=1326" | grep mkdir'
# audit: type=1326 ... comm="mkdir" exe="/bin/mkdir" ... syscall=83
```

`SCMP_ACT_LOG` writes an audit record to the kernel log and lets the call through (`SCMP_ACT_ERRNO` would block it).

## Question 4: Falco message for a shell in a container (`shell-watch`)

The default rule `Terminal shell in container` already detects the shell. With Falco's `rule_matching: first` a second rule with another name and the same condition never fires (the default rule matches the event first), so change the existing rule, in the local rules file, with an override. The value of `output` contains `: ` and must be quoted (or written as a folded `>` block), otherwise the YAML is invalid and Falco does not start:

```bash
ssh {{NODE02}}
cat > /etc/falco/falco_rules.local.yaml <<'EOF'
- rule: Terminal shell in container
  output: >
    CRITICAL: SHELL OPENED | user=%user.name command=%proc.cmdline container=%container.name
  priority: CRITICAL
  override:
    output: replace
    priority: replace
EOF
systemctl restart falco-modern-bpf
systemctl is-active falco-modern-bpf
```

Test it, from the jumphost, with a terminal (`-it`):

```bash
kubectl exec -it -n shell-watch shell-practice -- /bin/sh
ssh {{NODE02}} 'journalctl -u falco-modern-bpf --since "-1 min" | grep "SHELL OPENED"'
```

Other ways that work: copying the whole default rule with the new output into the local file (a later definition with the same name replaces the earlier one), editing the output in `falco_rules.yaml`, or disabling the default rule (`enabled: false` with `override: {enabled: replace}`) and adding your own rule. What does not work: a new rule with another name and the same condition (masked by the default rule), an unquoted `CRITICAL: SHELL OPENED` (invalid YAML: the service does not start; `falco -o engine.kind=modern_ebpf` on the node prints the error), or not restarting the service.

## Question 5: audit policy for Secrets (files)

```yaml
apiVersion: audit.k8s.io/v1
kind: Policy
rules:
- level: Metadata
  resources:
  - group: ""
    resources: ["secrets"]
```

The rule has no `namespaces`, `users` or `verbs`, so it covers every request for Secrets. `Metadata` records who did what without the content; `Request` or `RequestResponse` would write the Secret data into the audit log. The policy is not applied to the API server in this question (to do it: `--audit-policy-file` and `--audit-log-path`, with the log directory mounted).
