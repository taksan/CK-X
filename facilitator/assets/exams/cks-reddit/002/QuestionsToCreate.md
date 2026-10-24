Question 1

Enforce a prepared AppArmor profile on a specific worker node and deploy a Pod using it:

- Apply the `nginx-profile-2` AppArmor profile on the worker node `node-01`.
- Edit the Pod manifest to reference this profile.
- Deploy the Pod on `node-01` and ensure the profile is applied correctly.

Your answer is correct

solution

#### Explanation

AppArmor restricts container behavior for enhanced security. In this task, the profile `nginx-profile-2` denies all file writes. Depending on the Kubernetes version, the profile is applied via `securityContext` (≥v1.30) or annotations (<v1.30).

  

**Commands / Steps:**

  

1. # SSH into the worker node (if needed)
2. ssh node-01

3. # Switch to root
4. sudo -i

5. # View the prepared AppArmor profile
6. head /etc/apparmor.d/nginx_apparmor

7. # profile example
8. `#include <tunables/global>
9. profile nginx-profile-2 flags=(attach_disconnected) {
10.     #include <abstractions/base>
11.     file,
12.     # Deny all file writes.
13.     deny /** w,
14. }`

15. # Load the AppArmor profile
16. apparmor_parser -q /etc/apparmor.d/nginx_apparmor

17. # Verify that the profile is active
18. aa-status | grep -i nginx-profile-2

19. # Exit from the node
20. exit

  

21. # Pod manifest for Kubernetes ≥1.30
22. ---
23. apiVersion: v1
24. kind: Pod
25. metadata:
26.   name: nginx-pod
27. spec:
28.   nodeName: node-01
29.   containers:
30.   - name: nginx-pod
31.     image: nginx:1.19.0
32.     ports:
33.     - containerPort: 80
34.     securityContext:
35.       appArmorProfile:
36.         type: Localhost
37.         localhostProfile: nginx-profile-2

  

38. # Pod manifest for Kubernetes <1.30 (using annotations)
39. ---
40. apiVersion: v1
41. kind: Pod
42. metadata:
43.   name: nginx-pod
44.   annotations:
45.     container.apparmor.security.beta.kubernetes.io/nginx-pod: localhost/nginx-profile-2
46. spec:
47.   nodeName: node-01
48.   containers:
49.   - name: nginx-pod
50.     image: nginx:1.19.0
51.     ports:
52.     - containerPort: 80

  

53. # Apply the Pod manifest
54. kubectl create -f /home/candidate/nginx-pod.yaml

  

**Verification Step:**

- Check that the Pod is running on node-01:
    

1. kubectl get pods -o wide | grep nginx-pod

- Test that the AppArmor profile is enforced by attempting a restricted write:
    

1. kubectl exec -it nginx-pod -- /bin/sh
2. touch /restricted-directory/testfile
3. # The operation should fail due to AppArmor restrictions
4. exit

  

⚠️ Note:

- Container-level AppArmor profiles override pod-level profiles.
    
- Kubernetes ≥1.30 uses `securityContext.appArmorProfile`, while <1.30 uses annotations.
    
- Ensure AppArmor is enabled on the node before applying the profile
    

  

N/A

**Resources**

Domain

System Hardening (10%) ✅

Question 2

Create a NetworkPolicy named `deny-all` in the `testing` namespace that blocks all ingress and egress traffic for all pods in the namespace.

Your answer is correct

solution

#### Explanation

**NetworkPolicy manifest**

  

1. # netpol-deny-all.yaml
2. apiVersion: networking.k8s.io/v1
3. kind: NetworkPolicy
4. metadata:
5.   name: deny-all
6.   namespace: testing
7. spec:
8.   podSelector: {}  # selects all pods in the namespace
9.   policyTypes:
10.   - Ingress
11.   - Egress

  

12. kubectl apply -f netpol-deny-all.yaml

  

**Verification Step:**

- Confirm the policy is applied and restricting traffic correctly:
    

1. kubectl get netpol -n testing
2. kubectl describe netpol deny-all -n testing

  

N/A

**Resources**

Domain

Minimize Microservice Vulnerabilities (20%) ✅

Question 3

- A Pod `nginx-pod` is running in the `default` namespace and uses a token by default.
    
- Modify the default `ServiceAccount` to disable automatic token mounting.
    
- Create a Secret of type `kubernetes.io/service-account-token` that references the default ServiceAccount.
    
- Edit the Pod to:
    
    - Use the default ServiceAccount.
        
    - Mount the token from the Secret at `/var/run/secrets/kubernetes.io/serviceaccount/token`.
        

Your answer is correct

solution

#### Explanation

**Step 1: Disable auto-mount for the** `**default**` **ServiceAccount**

  

1. kubectl patch sa default -n default -p '{"automountServiceAccountToken": false}'

  

_Or edit directly_

  

1. kubectl edit sa default -n default

2. ---
3. apiVersion: v1
4. kind: ServiceAccount
5. metadata:
6.   name: default
7.   namespace: default
8. automountServiceAccountToken: false  # add this line

  

**Step 2: Create a Secret of type** `**kubernetes.io/service-account-token**` **that references the** `**default**` **ServiceAccount**

  

1. # default-sa-token.yaml
2. ---
3. apiVersion: v1
4. kind: Secret
5. metadata:
6.   name: default-sa-token
7.   annotations:
8.     kubernetes.io/service-account.name: "default"
9. type: kubernetes.io/service-account-token

  

10. kubectl apply -f default-sa-token.yaml

  

11. # Check that Kubernetes automatically injects the token
12. kubectl get secret default-sa-token -o jsonpath='{.data.token}' | base64 -d -w 0

  

**Step 3: Edit the Pod to mount the Secret**

  

1. ---
2. apiVersion: v1
3. kind: Pod
4. metadata:
5.   name: nginx-pod
6.   namespace: default
7. spec:
8.   serviceAccountName: default
9.   automountServiceAccountToken: false
10.   containers:
11.   - name: nginx
12.     image: nginx
13.     volumeMounts:
14.     - name: token-vol
15.       mountPath: /var/run/secrets/kubernetes.io/serviceaccount/
16.       readOnly: true
17.   volumes:
18.   - name: token-vol
19.     secret:
20.       secretName: default-sa-token

  

**Step 4: Verify inside the Pod**

  

1. kubectl exec -it nginx-pod -- cat /var/run/secrets/kubernetes.io/serviceaccount/token

  

**Explanation:**

- ServiceAccount `default` is disabled from auto-mounting tokens (`automountServiceAccountToken: false`)
    
- Created a Secret of type `kubernetes.io/service-account-token` that references the default ServiceAccount, auto-populated by kubelet
    
- Pod `nginx-pod` manually mounts token from Secret instead of projected volume
    
- Token type `kubernetes.io/service-account-token` is a `long-lived` legacy token (unlike projected tokens which are `short-lived`)
    

  

N/A

**Resources**

Domain

Cluster Hardening (15%) ✅

Question 4

- The cluster’s API server was temporarily configured to allow **unauthenticated + unauthorized access** (`anonymous` user had `**cluster-admin**`).
    
- Re-secure the cluster so that **only authenticated and authorized REST requests** are allowed.
    
- Requirements:
    
    - Use authorization mode `**Node,RBAC**`.
        
    - Use admission controller `**NodeRestriction**`.
        
    - Disable `**--anonymous-auth**`.
        
    - Remove `ClusterRoleBinding` that grants access to `**system:anonymous**`.
        
- After the fix, use the **original kubeconfig** `/etc/kubernetes/admin.conf` for authenticated kubectl access.
    

Your answer is correct

solution

#### Explanation

**Step 1: Secure kube-apiserver configuration**

  

Edit `/etc/kubernetes/manifests/kube-apiserver.yaml`:

  

1. - --authorization-mode=Node,RBAC
2. - --enable-admission-plugins=NodeRestriction
3. - --anonymous-auth=false
4. - --client-ca-file=/etc/kubernetes/pki/ca.crt

Remove any insecure options such as `**AlwaysAllow**` or `**AlwaysAdmit**`.

  

**Step 2: Remove** `**anonymous**` **ClusterRoleBinding**

  

Check and delete:

  

1. kubectl get clusterrolebinding | grep 'system:anonymous'
2. kubectl delete clusterrolebinding system:anonymous

  

**Step 4: Verify**

  

Check system pods to confirm access works with authenticated config:

  

1. kubectl get pods -n kube-system --kubeconfig /etc/kubernetes/admin.conf

  

⚠️ Note:

- Setting `**--anonymous-auth=false**` ensures no unauthenticated requests are processed.
    
- Authorization is now enforced via `**Node + RBAC**`.
    
- `**NodeRestriction**` admission controller prevents kubelets from modifying objects outside their scope.
    
- `**--client-ca-file**` ensures secure communication between API server and clients.
    
- After cleanup, only `authenticated + authorized` users (e.g., `kubernetes-admin`) can access the cluster
    

N/A

**Resources**

Domain

Cluster Hardening (15%) ✅

Question 5

Enable Kubernetes audit logging with custom retention and policy rules:

- Store audit logs at `/var/log/kubernetes-logs.log`.
    
- Retain logs for 5 days, maximum 10 old files, 100 MB per file.
    
- Extend audit policy to:
    
    1. Log CronJob changes at RequestResponse level.
        
    2. Log request bodies for deployments in `kube-system` namespace.
        
    3. Log all other core and extensions resources at Request level.
        
    4. Exclude watch requests by `system:kube-proxy` on endpoints or services.
        

Your answer is correct

solution

#### Explanation

Audit logging in Kubernetes tracks requests to the API server. Custom policies allow selective logging and exclusion to reduce noise. Audit backend rotation ensures logs do not consume excessive disk space.

  

**Commands / Steps:**

  

1. # Edit audit policy
2. vim /etc/audit/audit-policy.yaml

  

3. # /etc/audit/audit-policy.yaml
4. apiVersion: audit.k8s.io/v1
5. kind: Policy
6. rules:
7.   # 1. Log CronJobs changes at RequestResponse level
8.   - level: RequestResponse
9.     resources:
10.       - group: "batch"
11.         resources: ["cronjobs"]

12.   # 2. Log request body of deployments changes in kube-system
13.   - level: Request
14.     namespaces: ["kube-system"]
15.     resources:
16.       - group: "apps"
17.         resources: ["deployments"]

18.   # 3. Log all other core and extensions resources at Request level
19.   - level: Request
20.     resources:
21.       - group: ""
22.       - group: "extensions"

23.   # 4. Exclude watch requests by system:kube-proxy on endpoints/services
24.   - level: None
25.     users: ["system:kube-proxy"]
26.     verbs: ["watch"]
27.     resources:
28.       - group: ""
29.         resources: ["endpoints", "services"]

  

30. # Update kube-apiserver manifest to enable audit logging
31. vim /etc/kubernetes/manifests/kube-apiserver.yaml

  

32. # Relevant kube-apiserver spec snippet
33. spec:
34.   containers:
35.   - name: kube-apiserver
36.     image: k8s.gcr.io/kube-apiserver:v1.30.0
37.     command:
38.     - kube-apiserver
39.     - --audit-policy-file=/etc/audit/audit-policy.yaml
40.     - --audit-log-path=/var/log/kubernetes-logs.log
41.     - --audit-log-maxage=5
42.     - --audit-log-maxbackup=10
43.     - --audit-log-maxsize=100
44.     volumeMounts:
45.     - mountPath: /etc/audit/audit-policy.yaml
46.       name: audit
47.       readOnly: true
48.     - mountPath: /var/log/
49.       name: audit-log
50.       readOnly: false
51.   volumes:
52.   - name: audit
53.     hostPath:
54.       path: /etc/audit/audit-policy.yaml
55.       type: File
56.   - name: audit-log
57.     hostPath:
58.       path: /var/log/
59.       type: DirectoryOrCreate

  

60. # Verify kube-apiserver is running with audit logs
61. ps aux | grep kube-apiserver | grep audit

62. # Test logging by creating a CronJob
63. kubectl create cronjob testjob --image=busybox --schedule="*/1 * * * *" -- /bin/sh -c 'date; echo Hello'

64. # Check audit logs for CronJob entries
65. cat /var/log/kubernetes-logs.log | grep cronjob

66. # Follow the log file
67. tail -f /var/log/kubernetes-logs.log

  

**Verification Step:**

- Confirm the kube-apiserver is running with audit logging:
    

1. ps aux | grep kube-apiserver | grep audit

- Check that audit logs are being generated:
    

1. cat /var/log/kubernetes-logs.log | grep cronjob
2. tail -f /var/log/kubernetes-logs.log

- Verify CronJob requests appear with `RequestResponse` level.
    
- Ensure other rules are applied correctly and `system:kube-proxy` watch requests are excluded.
    
- Check log rotation and retention settings (`maxsize`, `maxbackup`, `maxage`).
    
      
    

⚠️ Note:

- Audit policies are applied per API server; manifest changes automatically restart kube-apiserver in static pod setup.
    
- Use `kubectl get cronjob` to trigger API server events for testing logging.
    
- Adjust logging levels to balance audit detail vs disk usage.
    

  

N/A

**Resources**

Domain

Monitoring, Logging and Runtime Security (20%) ✅

Question 6

You are given a Dockerfile and a Pod manifest. Both contain **security best practice violations** that need fixing.

Rules:

- Fix **two issues** in the Dockerfile.
    
- Fix **two issues** in the Pod manifest.
    
- Do not add or remove fields — only edit existing ones.
    
- When a non-root user is needed, use `test-user` with UID `5375`.
    
      
    

**_Given Files_**

  

**Dockerfile:**

  

1. FROM ubuntu:latest
2. RUN apt-get update -y
3. RUN apt-get install nginx -y
4. COPY entrypoint.sh /
5. ENTRYPOINT ["/entrypoint.sh"]
6. USER ROOT

  

**Pod manifest:**

  

1. ---
2. apiVersion: v1
3. kind: Pod
4. metadata:
5.   name: security-context-demo-2
6. spec:
7.   securityContext:
8.     runAsUser: 1000
9.   containers:
10.   - name: security-context-demo-2
11.     image: gcr.io/google-samples/node-hello:1.0
12.     securityContext:
13.       runAsUser: 0
14.       privileged: true
15.       allowPrivilegeEscalation: false

  

Your answer is correct

solution

#### Explanation

**Step 1: Fixed Dockerfile**

  

1. FROM ubuntu:20.04           # ✅ use fixed, stable version instead of 'latest'
2. RUN apt-get update -y
3. RUN apt-get install nginx -y    
4. COPY entrypoint.sh /
5. ENTRYPOINT ["/entrypoint.sh"]
6. USER test-user              # ✅ run as unprivileged user (test-user, UID 5375)

  

**Step 2: Fixed Pod manifest**

  

1. ---
2. apiVersion: v1
3. kind: Pod
4. metadata:
5.   name: security-context-demo-2
6. spec:
7.   securityContext:
8.     runAsUser: 1000
9.   containers:
10.   - name: security-context-demo-2
11.     image: gcr.io/google-samples/node-hello:1.0
12.     securityContext:
13.       runAsUser: 5375         # ✅ avoid running as root (use test-user UID 5375)
14.       privileged: false       # ✅ disable privileged mode
15.       allowPrivilegeEscalation: false

  

**Issues Fixed:**

**_Dockerfile_**

- `FROM ubuntu:latest` → `FROM ubuntu:20.04` → avoids unpredictability and vulnerabilities from `latest`.
    
- `USER ROOT` → `USER 5375` → prevents running as root (principle of least privilege).
    

**_Manifest_**

- `runAsUser: 0` → `runAsUser: 5375` → avoid root user inside container.
    
- `privileged: true` → `privileged: false` → prevents host-level privileges.
    
      
    

N/A

**Resources**

Domain

System Hardening (10%) ✅

Question 7

Fix multiple **security violations** identified by `**kube-bench**`.

- API Server:
    
    1. Enable `**RotateKubeletServerCertificate**`.
        
    2. Enable admission plugin `**PodSecurityPolicy**`.
        
    3. Set `**--kubelet-certificate-authority**` argument.
        
- Kubelet:
    
    1. Disable anonymous authentication.
        
    2. Set `**authorization-mode**` to `**Webhook**`.
        
- ETCD:
    
    1. Ensure `**--auto-tls**` is not `**true**`.
        
    2. Ensure `**--peer-auto-tls**` is not `**true**`.
        

Your answer is correct

solution

#### Explanation

**Step 1: Run kube-bench checks**

  

1. kube-bench run --targets=master,node,etcd
2. # Run master checks (apiserver, controller-manager, scheduler, etcd, kubelet-on-master)
3. kube-bench run --targets=master
4. # Run node (kubelet) checks
5. kube-bench run --targets=node --check "4.*"
6. # Run etcd checks
7. kube-bench run --targets=etcd

  

**Step 2: Fix API Server configuration**

  

Edit `/etc/kubernetes/manifests/kube-apiserver.yaml`:

  

1. # /etc/kubernetes/manifests/kube-apiserver.yaml (flags section)
2. - --authorization-mode=Node,RBAC
3. - --feature-gates=RotateKubeletServerCertificate=true
4. - --enable-admission-plugins=...,PodSecurityPolicy
5. - --kubelet-certificate-authority=/etc/kubernetes/pki/ca.crt

  

**Step 3: Fix Kubelet configuration**

  

Check kubelet process:

  

1. ps -ef | grep kubelet

  

Edit `/var/lib/kubelet/config.yaml`:

  

1. authentication:
2.   anonymous:
3.     enabled: false
4.   webhook:
5.     enabled: true
6.   x509:
7.     clientCAFile: /etc/kubernetes/pki/ca.crt

8. authorization:
9.   mode: Webhook

  

10. sudo systemctl daemon-reexec
11. sudo systemctl restart kubelet

  

**Step 4: Fix ETCD configuration**

  

Edit `/etc/kubernetes/manifests/etcd.yaml`:

  

1. # /etc/kubernetes/manifests/etcd.yaml (flags section)
2. - --auto-tls=false
3. - --peer-auto-tls=false

  

**Step 5: Verify fixes**

  

1. kube-bench run --targets=master,node,etcd
2. kubectl get pods -n kube-system

  

**Issues Fixed:**

**API Server:**

- Enforced `**RotateKubeletServerCertificate=true**`.
    
- Added admission plugin `**PodSecurityPolicy**`.
    
- Configured `**--kubelet-certificate-authority**` for secure kubelet communication.
    

**Kubelet:**

- Disabled anonymous authentication.
    
- Configured `**authorization-mode=Webhook**`
    

**ETCD:**

- Disabled `**--auto-tls**` and `**--peer-auto-tls**` to prevent insecure self-signed certs.
    

  

N/A

**Resources**

Domain

Cluster Setup (15%) ✅

Question 8

By default, Kubernetes stores Secrets in etcd in plaintext, which is **insecure**.

Your task is to **enable encryption at rest** for Secrets using an `EncryptionConfiguration` manifest with `AES-CBC` and `identity` providers, ensuring that all secrets are **encrypted** in etcd.

Your answer is correct

solution

#### Explanation

**Commands / Steps:**

  

1. # Generate a base64-encoded encryption key
2. head -c 32 /dev/urandom | base64

  

3. # /etc/kubernetes/enc/enc.yaml
4. apiVersion: apiserver.config.k8s.io/v1
5. kind: EncryptionConfiguration
6. resources:
7.   - resources:
8.       - secrets
9.     providers:
10.       - aescbc:
11.           keys:
12.             - name: key1
13.               secret: c2VjcmV0IGlzIHNlY3VyZSwgSSB0aGluaw==   # base64-encoded key
14.       - identity: {}

  

15. # Edit kube-apiserver manifest to enable encryption
16. vim /etc/kubernetes/manifests/kube-apiserver.yaml

  

17. ...
18. spec:
19.   containers:
20.   - command:
21.     - kube-apiserver
22.     ...
23.     - --encryption-provider-config=/etc/kubernetes/enc/enc.yaml
24.     volumeMounts:
25.     ...
26.     - name: enc
27.       mountPath: /etc/kubernetes/enc
28.       readOnly: true
29.   volumes:
30.   ...
31.   - name: enc
32.     hostPath:
33.       path: /etc/kubernetes/enc
34.       type: DirectoryOrCreate

  

35. # Create a test secret
36. kubectl create secret generic secret1 -n default --from-literal=mykey=mydata

  

37. # Verify encryption in etcd
38. ETCDCTL_API=3 etcdctl \
39.    --cacert=/etc/kubernetes/pki/etcd/ca.crt \
40.    --cert=/etc/kubernetes/pki/etcd/server.crt \
41.    --key=/etc/kubernetes/pki/etcd/server.key \
42.    get /registry/secrets/default/secret1 | hexdump -C

43. # Ensure all existing secrets are re-encrypted with the new configuration
44. kubectl get secrets --all-namespaces -o json | kubectl replace -f -
45. ETCDCTL_API=3 etcdctl \
46.    --cacert=/etc/kubernetes/pki/etcd/ca.crt \
47.    --cert=/etc/kubernetes/pki/etcd/server.crt \
48.    --key=/etc/kubernetes/pki/etcd/server.key \
49.    get /registry/secrets/default/secret1 | hexdump -C

  

**Verification Step:**

  

1. # Confirm that the secret data in etcd is not plaintext
2. ETCDCTL_API=3 etcdctl \
3.    --cacert=/etc/kubernetes/pki/etcd/ca.crt \
4.    --cert=/etc/kubernetes/pki/etcd/server.crt \
5.    --key=/etc/kubernetes/pki/etcd/server.key \
6.    get /registry/secrets/default/secret1 | hexdump -C

  

⚠️ Note:

- `aescbc` provider encrypts secret data at rest; `identity` allows unencrypted fallback (for non-secret resources).
    
- Re-applying all secrets (`kubectl get secrets | kubectl replace -f -`) ensures previously created secrets are encrypted.
    
- ETCD secrets are stored at `/registry/secrets/<namespace>/<secret>`; use `etcdctl` to inspect them.
    
- Ensure that the encryption key is safely backed up and rotated periodically.
    
- Requires API server restart after modifying encryption configuration.
    
      
    

N/A

**Resources**

Domain

Minimize Microservice Vulnerabilities (20%) ✅

Question 9

Ensure that all Pods in the `prod` namespace follow the best practices of being **stateless** and **immutable**. Identify and delete any Pods that store data in container volumes (**stateful**) or are configured as `privileged`/with `writable root filesystems` (**not immutable**).

Your answer is correct

solution

#### Explanation

**Stateless** Pods should not store persistent data inside containers, and **immutable** Pods should not run as `privileged` and must have `readOnlyRootFilesystem: true`.

Any Pod violating these rules should be deleted to maintain cluster security and best practices.

  

**Commands / Steps**

  

1. # Inspect Pods for security context settings

2. kubectl get pod/app -n prod -o yaml | grep -E 'privileged|readOnlyRootFilesystem'
3. kubectl get pod/frontend -n prod -o yaml | grep -E 'privileged|readOnlyRootFilesystem'
4. kubectl get pod/gcc -n prod -o yaml | grep -E 'privileged|readOnlyRootFilesystem'

5. # Check which Pods have volumes attached (potentially stateful)

6. kubectl get pods -n prod -o jsonpath="{range .items[*]}{.metadata.name}{': '}{.spec.volumes[*].name}{'\n'}{end}"

7. # Inspect volumeMounts for a specific Pod

8. kubectl get pod/frontend -n prod -o yaml | grep volumeMounts -A 5

9. # Delete Pods that are either stateful or not immutable

10. kubectl delete --grace-period=0 --force pod app -n prod
11. kubectl delete --grace-period=0 --force pod gcc -n prod

  

**Verification Step:**

  

1. # Verify remaining Pods follow stateless and immutable principles

2. kubectl get pods -n prod -o yaml | grep -E 'privileged|readOnlyRootFilesystem'
3. kubectl get pods -n prod -o jsonpath="{range .items[*]}{.metadata.name}{': '}{.spec.volumes[*].name}{'\n'}{end}"
4. kubectl get pod/frontend -n prod -o yaml | grep volumeMounts -A 5

  

⚠️ Note:

- **Stateless**: Pods should not persist data inside `hostPath` or `persistentVolumeClaim` volumes. `emptyDir` is considered stateless since its content is ephemeral.
    
- **Immutable**: Pods should not run as privileged and must have `readOnlyRootFilesystem: true`. Must have `readOnlyRootFilesystem: true` and `privileged: false`
    
- `ConfigMap/Secret` Volumes: May introduce state if the container can modify the mounted files.
    
- Always verify both `securityContext` and mounted volumes when evaluating Pod **immutability and statelessness**.
    

  

N/A

**Resources**

Domain

Minimize Microservice Vulnerabilities (20%) ✅

Question 10

The cluster uses containerd with `runc` as the default runtime.

It has been prepared to support an additional runtime handler, `runsc` (gVisor).

Create a `RuntimeClass` named `sandboxed` using `runsc`, and update all Pods in the `server` namespace to use this runtime.

`/home/candidate/10/runtime-class.yaml`

Your answer is correct

solution

#### Explanation

**Commands / Steps**

  

1. # Create the RuntimeClass
2. vim /home/candidate/10/runtime-class.yaml

  

3. # runtime-class.yaml
4. apiVersion: node.k8s.io/v1
5. kind: RuntimeClass
6. metadata:
7.   name: "sandboxed"
8. handler: "runsc"

  

9. # Apply the RuntimeClass
10. kubectl create -f /home/candidate/10/runtime-class.yaml

11. # List all deployments in the server namespace
12. kubectl get deployments -n server

13. # List all Pods in the server namespace
14. kubectl get pods -n server

15. # Edit each deployment to add the runtimeClassName
16. kubectl edit deploy -n server workload1

  

17. # Within spec.template.spec of workload1 deployment
18. runtimeClassName: sandboxed

  

19. # Repeat for other deployments
20. kubectl edit deploy -n server workload2
21. kubectl edit deploy -n server workload3

22. # Verify the change
23. kubectl get deploy -n server workload1 -o yaml | grep runtimeClassName
24. kubectl get deploy -n server workload2 -o yaml | grep runtimeClassName
25. kubectl get deploy -n server workload3 -o yaml | grep runtimeClassName

26. # Pods should now use the 'sandboxed' RuntimeClass
27. kubectl get pods -n server -o jsonpath="{range .items[*]}{.metadata.name}{': '}{.spec.runtimeClassName}{'\n'}{end}"

  

⚠️ Note:

- `runtimeClassName` is added under `spec.template.spec` in Deployments.
    
- Pods will be recreated automatically after updating the Deployment to use the new RuntimeClass.
    
- gVisor (`runsc`) provides extra security by sandboxing containers but may have performance trade-offs.
    

N/A

**Resources**

Domain

Minimize Microservice Vulnerabilities (20%) ✅

Question 11

The cluster has a container image scanner webhook but its configuration is incomplete.

Current configuration is in `/etc/kubernetes/confcontrol` directory.

Enable the ImagePolicy admission plugin, set it to deny all non-compliant images (implicit deny), and test the configuration by attempting to deploy a Pod using the `latest` image tag.

Your answer is correct

solution

#### Explanation

The `**ImagePolicyWebhook**` ensures that only validated container images are allowed.

Configuring it with `**defaultAllow: false**` enforces **implicit deny**, preventing use of unapproved or potentially vulnerable images.

  

**Commands / Steps**

  

1. # Inspect the current configuration directory
2. ls /etc/kubernetes/confcontrol

  

3. # /etc/kubernetes/confcontrol/admission_configuration.yaml
4. apiVersion: apiserver.config.k8s.io/v1
5. kind: AdmissionConfiguration
6. plugins:
7.   - name: ImagePolicyWebhook
8.     configuration:  
9.       imagePolicy:
10.         kubeConfigFile: /etc/kubernetes/confcontrol/kubeconfig.yaml
11.         allowTTL: 50
12.         denyTTL: 50
13.         retryBackoff: 500
14.         defaultAllow: false

  

15. # /etc/kubernetes/confcontrol/kubeconfig.yaml
16. apiVersion: v1
17. kind: Config
18. clusters:
19. - name: test-server
20.   cluster:
21.     certificate-authority: /etc/kubernetes/confcontrol/webhook.pem
22.     server: https://test-server.local.8081/image_policy
23. users:
24. - name: apiserver
25.   user:
26.     client-certificate: /etc/kubernetes/confcontrol/apiserver-client.pem
27.     client-key: /etc/kubernetes/confcontrol/apiserver-client-key.pem
28. contexts:
29. - name: webhook-context
30.   context:
31.     cluster: test-server
32.     user: apiserver
33. current-context: webhook-context

  

34. # Update the kube-apiserver manifest to enable the admission plugin
35. vim /etc/kubernetes/manifests/kube-apiserver.yaml

  

36. # Relevant kube-apiserver.yaml snippet
37. - --enable-admission-plugins=NodeRestriction,ImagePolicyWebhook
38. - --admission-control-config-file=/etc/kubernetes/confcontrol/admission_configuration.yaml
39. volumeMounts:
40.   - name: image-policy-config
41.     mountPath: /etc/kubernetes/confcontrol
42.     readOnly: true
43. volumes:
44.   - name: image-policy-config
45.     hostPath:
46.       path: /etc/kubernetes/confcontrol
47.       type: DirectoryOrCreate

  

48. # Test the configuration by deploying a Pod with latest tag
49. kubectl run pod-latest --image=nginx:latest

  

50. # Expected output:
51. Error from server (Forbidden): pods "pod-latest" is forbidden: image policy webhook backend denied one or more images: Images using latest tag are not allowed

  

**Verification Step:**

1. # The Pod creation should be denied
2. kubectl get pods -n default | grep pod-latest

  

⚠️ Note:

- Ensure `defaultAllow`: false is set to enforce implicit deny.
    
- The webhook requires a valid HTTPS endpoint with correct certificates.
    
- Use troubleshooting commands if kube-apiserver fails:
    

1. crictl ps -a | grep kube-api
2. journalctl -u kubelet -f
3. systemctl restart kubelet
4. kubectl -n kube-system logs -l component=kube-apiserver

  

N/A

**Resources**

Domain

Supply Chain Security (20%) ✅

Question 12

A Pod in the namespace `dev-ops` is mounting `/var/run/docker.sock` from the host.

This gives the container **privileged access to the host’s Docker daemon**, which is a serious security risk.

Identify the Pod(s) mounting `docker.sock` and update their Deployment(s) to remove the volume mount.

Verify that the containers can no longer access `/var/run/docker.sock`.

Your answer is correct

solution

#### Explanation

**Step 1: Identify Pods mounting** `**/var/run/docker.sock**`

  

1. kubectl get pods -n dev-ops -o jsonpath='{range .items[*]}{.metadata.name}{" - "}{.spec.containers[*].name}{"\n"}{end}'
2. kubectl get pods -n dev-ops -o yaml | grep -A 3 "hostPath.*docker.sock"

  

Example output:

  

1. docker-hacker-7d9f8   container1
2. # volumeMounts:
3. # - mountPath: /var/run/docker.sock
4. #   name: dockersock

  

**Step 2: Identify the Deployment managing the Pod**

  

1. kubectl get deploy -n dev-ops
2. kubectl describe pod docker-hacker-7d9f8 -n dev-ops
3. # Look for OwnerReferences -> Deployment

  

**Step 3: Edit Deployment to remove** `**/var/run/docker.sock**` **mount**

  

1. kubectl edit deploy docker-hacker -n dev-ops

  

Modify the spec.template.spec.containers.volumeMounts section:

  

1. volumeMounts:
2.   # remove the entry:
3.   # - mountPath: /var/run/docker.sock
4.   #   name: dockersock

  

Also remove the corresponding volumes entry:

  

1. volumes:
2.   # remove the entry:
3.   # - name: dockersock
4.   #   hostPath:
5.   #     path: /var/run/docker.sock

  

**Step 4: Verify the Pod is recreated without** `**/var/run/docker.sock**`

  

1. kubectl rollout status deploy/docker-hacker -n dev-ops
2. kubectl get pods -n dev-ops -o yaml | grep -A 3 "docker.sock"

  

Expected: No Pod should have `/var/run/docker.sock` mounted.

  

**Step 5: Optional validation inside container**

  

1. kubectl exec -it <pod-name> -n dev-ops -- ls -l /var/run/docker.sock
2. # Expected: ls: cannot access '/var/run/docker.sock': No such file or directory

  

**Explanation**

- Mounting `/var/run/docker.sock` allows a container to control the Docker daemon on the host, including creating or deleting containers and modifying the host filesystem.
    
- Removing the volume mount mitigates this privilege escalation risk.
    
- Always ensure sensitive host paths like `/var/run/docker.sock` are not mounted into untrusted Pods.
    
      
    

⚠️ Note:

- In real environments, consider using Pod Security `Policies / Pod Security Admission / seccomp` to prevent hostPath mounts like `docker.sock.`
    
- Any container that truly requires Docker access should run on a dedicated, isolated host.
    

  

N/A

**Resources**

Domain

Minimize Microservice Vulnerabilities (20%) ✅

Question 13

Enable **Istio Mutual TLS** `**(mTLS)**` **in** `**STRICT**` **mode** for all workloads in the namespace `payments`.

Before enforcing `**mTLS**`, verify that automatic **Istio Sidecar Injection** is enabled for the namespace.

After enforcement, confirm that all Pods communicate using `**mTLS**`.

Your answer is correct

solution

#### Explanation

**Step 1: Verify automatic Sidecar Injection**

Istio sidecar injection should be enabled for the namespace before enforcing `mTLS`:

  

1. kubectl get namespace payments --show-labels
2. # Check for label: istio-injection=enabled

  

If not present, enable it:

  

1. kubectl label namespace payments istio-injection=enabled --overwrite
2. kubectl get namespace payments --show-labels

  

⚠️ **Important:**

- If Pods were created **before** the label was added, they do not have sidecars.
    
- In that case, you must restart/recreate the Pods so that sidecars are injected (e.g., `kubectl rollout restart deployment -n payments`).
    
- If Pods already had sidecars, no restart is required.
    
      
    

**Step 2: Enforce** `**mTLS**` **in** `**STRICT**` **mode**

  

1. kubectl get pod -n payments

  

Create a `PeerAuthentication` resource for the namespace:

  

1. # payments-mtls.yaml
2. apiVersion: security.istio.io/v1
3. kind: PeerAuthentication
4. metadata:
5.   name: payments-mtls-strict
6.   namespace: payments
7. spec:
8.   mtls:
9.     mode: STRICT

  

10. kubectl apply -f payments-mtls.yaml

  

**Step 3: Verify** `**mTLS**` **enforcement**

  

1. # List PeerAuthentication policies
2. kubectl get peerauthentication -n payments

3. # Confirm sidecar containers in all pods
4. kubectl get pods -n payments -o jsonpath='{range .items[*]}{.metadata.name}{" - "}{.spec.containers[*].name}{"\n"}{end}'  # optional

5. # Test mTLS enforcement between Pods
6. kubectl exec -it <pod1> -n payments -- curl -v http://<pod2>.<payments>.svc.cluster.local

  

**Explanation**

- `Sidecar Injection`: Istio mTLS requires the Envoy sidecar in each Pod to handle certificate-based encryption.
    
- `PeerAuthentication STRICT mode`: All traffic within the namespace must use mTLS. Any plain text connections are denied.
    
- `Validation`: Ensures both the sidecar is present and that the PeerAuthentication policy is applied.
    
      
    

⚠️ Notes:

- `**mTLS STRICT**` will reject any Pod traffic without a sidecar or without valid Istio certificates.
    
- Always verify that new workloads in the namespace inherit sidecar injection.
    

  

N/A

**Resources**

Domain

Minimize Microservice Vulnerabilities (20%) ✅

Question 14

The namespace `secure-team` is configured with **Pod Security Admission** label enforcing `restricted` profile.

You are given a Deployment manifest `/home/masters/insecure-deployment.yaml` that fails to start because it violates the `restricted` Pod Security Standard.

Your task is to edit the YAML to fix each of these issues and get the Deployment running successfully in `secure-team` namespace.

Your answer is correct

solution

#### Explanation

**Commands / Steps**

  

1. kubectl get ns secure-team --show-labels
2. # secure-team   pod-security.kubernetes.io/enforce=restricted

  

3. kubectl apply -f /home/masters/insecure-deployment.yaml

  

During each failed attempt while applying the YAML manifest of the given Deployment, the error message in the terminal explicitly indicates which `**securityContext**` property is non-compliant, making it easy to fix:

  

1. Error: pods "webapp-5c7f6d5c7f-xyz" is forbidden: violates PodSecurity "restricted:latest": spec.containers[0].securityContext.privileged = true
2. Error: pods "webapp-5c7f6d5c7f-xyz" is forbidden: violates PodSecurity "restricted:latest": spec.containers[0].securityContext.runAsUser = 0
3. Error: pods "webapp-5c7f6d5c7f-xyz" is forbidden: violates PodSecurity "restricted:latest": spec.volumes[0].hostPath = /tmp
4. Error: pods "webapp-5c7f6d5c7f-xyz" is forbidden: violates PodSecurity "restricted:latest": spec.containers[0].securityContext.capabilities.add = ["NET_ADMIN"]

  

**Inspect the Deployment YAML**

  

1. ---
2. apiVersion: apps/v1
3. kind: Deployment
4. metadata:
5.   name: webapp
6.   namespace: secure-team
7. spec:
8.   replicas: 1
9.   selector:
10.     matchLabels:
11.       app: webapp
12.   template:
13.     metadata:
14.       labels:
15.         app: webapp
16.     spec:
17.       containers:
18.       - name: webapp
19.         image: nginx:1.23
20.         ports:
21.         - containerPort: 80
22.         securityContext:
23.           privileged: true        # ❌ triggers: .securityContext.privileged=true
24.           runAsUser: 0            # ❌ triggers: .securityContext.runAsUser=0
25.           capabilities:
26.             add: ["NET_ADMIN"]    # ❌ triggers: .capabilities.add=["NET_ADMIN"]
27.         volumeMounts:
28.         - mountPath: /data
29.           name: host-data         # ❌ triggers: spec.volumes[0].hostPath = /tmp
30.       volumes:
31.       - name: host-data
32.         hostPath:
33.           path: /tmp

  

**Modify Deployment to comply with** `**restricted**` **profile**

  

1. apiVersion: apps/v1
2. kind: Deployment
3. metadata:
4.   name: webapp
5.   namespace: secure-team
6. spec:
7.   replicas: 1
8.   selector:
9.     matchLabels:
10.       app: webapp
11.   template:
12.     metadata:
13.       labels:
14.         app: webapp
15.     spec:
16.       containers:
17.       - name: webapp
18.         image: nginx:1.23
19.         ports:
20.         - containerPort: 80
21.         securityContext:
22.           runAsNonRoot: true
23.           runAsUser: 65535
24.           allowPrivilegeEscalation: false
25.           readOnlyRootFilesystem: true
26.           capabilities:
27.             drop: ["ALL"]
28.         volumeMounts:
29.         - mountPath: /data
30.           name: empty-vol
31.       volumes:
32.       - name: empty-vol
33.         emptyDir: {}

  

**Apply the modified Deployment**

  

1. kubectl apply -f /home/masters/insecure-deployment.yaml

  

**Verify the Deployment is running**

  

1. kubectl get deploy webapp -n secure-team
2. kubectl get pods -n secure-team

  

**Explanation**

  

- `**restricted**` Pod Security Standard forbids:
    
    - Privileged containers
        
    - Running as root
        
    - HostPath volumes
        
    - Adding capabilities
        
- Using `**emptyDir**` volume and unprivileged user satisfies the policy.
    
- Security context ensures:
    
    - Non-root execution (`**runAsNonRoot: true**`, `**runAsUser: 65535**`)
        
    - Read-only filesystem (`**readOnlyRootFilesystem: true**`)
        
    - No privilege escalation (`**allowPrivilegeEscalation: false**`)
        
    - All Linux capabilities dropped (`**capabilities: drop: ["ALL"]**`)
        
- After modification, the Pod **launches successfully** in `**secure-team**` namespace.
    

  

N/A

**Resources**

Domain

Minimize Microservice Vulnerabilities (20%) ✅

Question 15

The `supply-chain` namespace runs several Pods. Use **Trivy** to scan the container images they use.

1. Delete every Pod whose image contains at least one `CRITICAL` vulnerability. Keep the Pods whose images have none.
2. Save the scan result of the image used by Pod `legacy-web`, showing only `CRITICAL` vulnerabilities, to `/tmp/exam/cks-002-q15/legacy-web-critical.txt`.

Your answer is correct

solution

#### Explanation

**Commands / Steps:**

1. # List the images used in the namespace
2. kubectl get pods -n supply-chain -o custom-columns=NAME:.metadata.name,IMAGE:.spec.containers[*].image

3. # Scan each image for CRITICAL vulnerabilities
4. trivy image --severity CRITICAL nginx:1.14.2
5. trivy image --severity CRITICAL httpd:2.4.39
6. trivy image --severity CRITICAL busybox:1.36.1

7. # Delete the Pods whose images have CRITICAL vulnerabilities
8. kubectl delete pod legacy-web old-httpd -n supply-chain

9. # Save the CRITICAL-only report for the legacy-web image
10. trivy image --severity CRITICAL nginx:1.14.2 > /tmp/exam/cks-002-q15/legacy-web-critical.txt

**Verification Step:**

- `kubectl get pods -n supply-chain` shows only the `tools` Pod.
- The report file lists only `CRITICAL` CVEs.

⚠️ Note:

- Trivy needs internet access to download its vulnerability database on first use.

N/A

**Resources**

Domain

Supply Chain Security (20%) ✅

Question 16

Cluster security monitoring revealed that a malicious container is attempting to access `/dev/mem`, which represents direct access to physical memory.

Such activity is highly dangerous as it may lead to privilege escalation or kernel bypass.

Use **Falco** (or sysdig) to detect the malicious Pod and its Deployment, then scale the Deployment replicas to `0` to stop the workload.

Your answer is correct

solution

#### Explanation

**Commands / Steps**

  

**Create a custom Falco rule file** `**rule.yaml**`**:**

  

1. - rule: read write below /dev/mem
2.   desc: An attempt to read or write to /dev/mem directory
3.   condition: >
4.     ((evt.is_open_read=true or evt.is_open_write=true) and fd.name contains /dev/mem)
5.   output: "Process %proc.name accessed /dev/mem (command=%proc.cmdline user=%user.name container=%container.id image=%container.image.repository pod_name=%k8s.pod.name namespace=%k8s.ns.name)"
6.   priority: WARNING
7.   tags: [security]

  

**Run Falco** `**manually**` **with the** `**custom rule file**`**:**

  

1. falco -r rule.yaml  | grep -i 'dev/mem'

  

**Check Falco output/logs for alerts:**

  

1. # Example alert:
2. 23:15:42.567890: Warning Process evil-binary accessed /dev/mem (command=evil-binary user=root container=abc123 image=malicious/image pod_name=mem-hacker-7d89d9c7f8-xyz namespace=default)

  

3. → Pod: mem-hacker-7d89d9c7f8-xyz
4. → Namespace: default
5. → Deployment: mem-hacker

  

**Identify the Deployment that owns the container if only** `**container ID**` **is available, map it back to** `**Pod/Deployment**`**:**

  

1. # Using crictl to find the container
2. crictl ps -id abc123
3. crictl pods -id <pod_id>
4. kubectl get pod -A | grep mem-hacker

  

**Scale the Deployment replicas to** `**0**`**:**

  

1. kubectl scale deployment mem-hacker --replicas=0 -n default

  

**Verify scaling:**

  

1. kubectl get deploy mem-hacker -n default

  

Expected output:

  

1. NAME         READY   UP-TO-DATE   AVAILABLE   AGE
2. mem-hacker   0/0     0            0           1m

  

**Explanation of Falco Rule:**

  

- Falco rules use system call fields to filter events. For /dev/mem monitoring:
    
- `evt.is_open_read=true` → matches syscalls like `open`, `openat`, `openat2`, `open_by_handle_at` with read flag.
    
- `evt.is_open_write=true` → same syscalls but with write flag.
    
- Combined condition detects attempts to open `/dev/mem` with read or write permissions.
    

👉 If you also want to detect actual read/write operations:

  

1. ((evt.is_open_read=true or evt.is_open_write=true) or evt.type in (read, write)) and fd.name contains /dev/mem

👉 If you want to monitor only open attempts:

  

1. (evt.is_open_read=true or evt.is_open_write=true) and fd.name contains /dev/mem

  

⚠️ **Common mistake:**

- Writing something like:
    

1. evt.is_open_read=true and evt.type=read

will never match, because `evt.is_open_read` exists only for _open-related syscalls_, not for _read/write syscalls_.

  

⚠️ Note:

- Created a Falco rule to detect `/dev/mem` access.
    
- Ran Falco and caught the malicious Pod.
    
- Identified the Deployment (`mem-hacker`).
    
- Scaled replicas to 0 to stop the attack.
    
- `open_by_handle_at`: this is a rare syscall used in advanced file APIs. Falco includes it so that rules reliably cover all ways a process might open a file.
    

  

N/A

**Resources**

Domain

Monitoring, Logging and Runtime Security (20%) ✅