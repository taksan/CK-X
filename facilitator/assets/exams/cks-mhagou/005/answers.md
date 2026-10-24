# CKS - MHagou - Exam 5: answer key

Every command below was run against the lab cluster (kubeadm, `{{CONTROL_PLANE}}`, `{{NODE01}}`, `{{NODE02}}`, Cilium).
Based on the labs of the MHagou/CKS-prep collection, adapted to this cluster.

---

## Question 1: NetworkPolicies for the backends (`network-security`)

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: security-network-policy
  namespace: network-security
spec:
  podSelector:
    matchLabels:
      app: backend
  policyTypes: [Ingress, Egress]
  ingress:
  - from:
    - podSelector:
        matchLabels:
          app: frontend
    ports:
    - {protocol: TCP, port: 8080}
  egress:
  - to:
    - podSelector:
        matchLabels:
          app: database
    ports:
    - {protocol: TCP, port: 5432}
```

A `podSelector` alone in `from`/`to` only selects Pods of the policy's own namespace, which is what excludes `network-security-peer/frontend` and the peer database. A `namespaceSelector: {}` in the same peer would open every namespace. Test with:

```bash
kubectl exec -n network-security frontend -- wget -q -T 3 -O- http://$(kubectl get pod backend-a -n network-security -o jsonpath='{.status.podIP}'):8080
kubectl exec -n network-security-peer frontend -- wget -q -T 3 -O- http://<backend-a IP>:8080     # must time out
```

## Question 2: Ingress with TLS (`secure-ingress`)

```bash
kubectl -n secure-ingress create ingress secure-app --rule="secure-app.example.com/*=web-service:80,tls=secure-app-tls"
```

or

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: secure-app
  namespace: secure-ingress
spec:
  tls:
  - hosts: [secure-app.example.com]
    secretName: secure-app-tls
  rules:
  - host: secure-app.example.com
    http:
      paths:
      - {path: /, pathType: Prefix, backend: {service: {name: web-service, port: {number: 80}}}}
```

Traefik is the default IngressClass, so no `ingressClassName` is needed. The TLS `hosts` must be a host that the same Ingress routes and that the certificate covers (`kubectl get secret secure-app-tls -n secure-ingress -o jsonpath='{.data.tls\.crt}' | base64 -d | openssl x509 -noout -text | grep -A1 Alternative`). Check with `curl -sk --resolve secure-app.example.com:443:<traefik ip> https://secure-app.example.com/` (`kubectl get svc -n traefik`).

## Question 3: Pod Security Standards and RBAC (`api-security`)

```bash
kubectl label namespace api-security pod-security.kubernetes.io/enforce=baseline
```

```yaml
apiVersion: v1
kind: Pod
metadata: {name: secure-pod, namespace: api-security}
spec:
  containers:
  - name: app
    image: busybox:1.36.1
    command: ["sleep", "3600"]
    securityContext:
      runAsUser: 1000
      runAsNonRoot: true
      allowPrivilegeEscalation: false
      capabilities: {drop: ["ALL"]}
```

```bash
kubectl create serviceaccount pss-viewer -n api-security
kubectl create role pss-viewer-role -n api-security --verb=get --resource=namespaces
kubectl create rolebinding pss-viewer-binding -n api-security --role=pss-viewer-role --serviceaccount=api-security:pss-viewer
kubectl auth can-i get namespace/api-security --as=system:serviceaccount:api-security:pss-viewer     # yes
```

A Role in `api-security` can grant `get` on the Namespace object `api-security` itself (the API treats the namespace name as the namespace of the request); it grants nothing on other namespaces. An image that must write to root-owned paths (for example the official `nginx` image, which writes `/run/nginx.pid`) does not start as a non-root user: choose an image that can, or set `runAsUser` to the image's own user and check `kubectl get pod`.

## Question 4: block the metadata address (`metadata-protect`)

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata: {name: block-metadata, namespace: metadata-protect}
spec:
  podSelector: {}
  policyTypes: [Egress]
  egress:
  - to:
    - ipBlock:
        cidr: 0.0.0.0/0
        except: ["169.254.169.254/32"]
```

The validators evaluate the policy with the Kubernetes NetworkPolicy semantics (the metadata service does not exist here, so a connection test could not tell a block from an unreachable address). Note: with a CNI like Cilium an `ipBlock` only matches addresses outside the cluster, so such a policy also cuts the traffic of the Pod to cluster Pods and DNS; keep that in mind on a real cluster (an additional `to` rule for the namespaces/DNS would be needed).

## Question 5: checksums of kubectl and kubelet (`{{CONTROL_PLANE}}`)

```bash
ssh {{CONTROL_PLANE}}
mkdir -p /tmp/exam/mhagou-005-q5
sha256sum $(command -v kubectl) $(command -v kubelet) | tee /tmp/exam/mhagou-005-q5/verified-hashes.txt
```

The binaries are the ones installed on the node, not those of the jumphost. Use `sha256sum` (not `sha512sum`).

## Question 6: least-privilege RBAC (`rbac-minimize`)

```bash
kubectl create role app-reader-role -n rbac-minimize --verb=get,list,watch --resource=pods,services,deployments.apps
kubectl create rolebinding app-reader-binding -n rbac-minimize --role=app-reader-role --serviceaccount=rbac-minimize:app-reader
kubectl auth can-i list deployments.apps --as=system:serviceaccount:rbac-minimize:app-reader -n rbac-minimize
```

Built-in ClusterRoles such as `view` grant more than asked (ConfigMaps, endpoints, ...), and a ClusterRoleBinding would grant access in every namespace.

## Question 7: ServiceAccount without automounted token (`service-account-caution`)

```yaml
apiVersion: v1
kind: ServiceAccount
metadata: {name: minimal-sa, namespace: service-account-caution}
automountServiceAccountToken: false
---
apiVersion: apps/v1
kind: Deployment
metadata: {name: secure-app, namespace: service-account-caution}
spec:
  replicas: 2
  selector: {matchLabels: {app: secure-app}}
  template:
    metadata: {labels: {app: secure-app}}
    spec:
      serviceAccountName: minimal-sa
      automountServiceAccountToken: false
      containers:
      - {name: nginx, image: "nginx:stable"}
```

Setting it on the ServiceAccount is enough for the Pods; the Pod-level field is also valid and overrides the ServiceAccount (a Pod that sets `true` gets the token). Check: `kubectl exec -n service-account-caution deploy/secure-app -- ls /var/run/secrets/kubernetes.io/serviceaccount` fails.

## Question 8: restrict the API access of a namespace (`api-restrict`)

```bash
kubectl get svc kubernetes -n default                       # ClusterIP (10.96.0.1) and port 443
kubectl get endpoints kubernetes                            # the real address: 192.168.99.200:6443
```

On this cluster (Cilium) the policy is applied to the real address of the API server, so the Service address alone is not what traffic looks like to the network plugin. Block the API for every Pod and give the admin Pods an explicit rule:

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata: {name: api-server-policy, namespace: api-restrict}
spec:
  podSelector: {}
  policyTypes: [Egress]
  egress:
  - to:
    - ipBlock:
        cidr: 0.0.0.0/0
        except: ["10.96.0.1/32"]
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata: {name: allow-admin-api-egress, namespace: api-restrict}
spec:
  podSelector: {matchLabels: {role: admin}}
  policyTypes: [Egress]
  egress:
  - {}
```

What was tested on this cluster (Cilium):

- The two policies above block `restricted-pod` and keep the API reachable for `admin-pod`. An `ipBlock` rule only matches addresses outside the cluster, so the API server (a cluster entity after the Service address is translated) is not covered by `0.0.0.0/0 except ...`: that is why the API is blocked for ordinary Pods.
- The admin Pods need a rule that really covers the API traffic: `egress: [{}]` (everything) works. An `ipBlock` for the API endpoint (`192.168.99.200/32`, port 6443) or for the ClusterIP does **not** let the traffic through on this cluster, because the plugin does not evaluate the API server as a CIDR. Test from the Pod instead of trusting the address.
- "All other egress remains allowed" is judged with the NetworkPolicy semantics for external addresses: a policy that only denies everything for `restricted-pod` blocks the API but also the rest and loses that item.

---

## Notes on this exam

- Questions 4 and 8 judge "all other egress stays allowed" with the NetworkPolicy semantics for external addresses (an `ipBlock` or a rule without destination), while the API access of Question 8 is tested with real requests.
- The original labs were written for a Killercoda playground (a control plane and a worker); here the control plane is `{{CONTROL_PLANE}}` and the files are under `/tmp/exam/mhagou-005-q5` (Question 5).
