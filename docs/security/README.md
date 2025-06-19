
# Security Guide
This guide covers security best practices, configurations, and procedures for our K3s-based infrastructure platform.
## 🛡️ Security Overview
Our security model follows defense-in-depth principles across multiple layers:

- **Infrastructure Security**: Node hardening, network segmentation, access controls
- **Cluster Security**: RBAC, network policies, pod security standards
- **Application Security**: Container security, secrets management, vulnerability scanning
- **Operational Security**: Monitoring, logging, incident response
## 🔐 Authentication & Authorization

### RBAC (Role-Based Access Control)

#### Service Account Management

```yaml

# Example: Read-only service account for monitoring

apiVersion: v1
kind: ServiceAccount
metadata:
  name: monitoring-reader
  namespace: monitoring
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: monitoring-reader
rules:
- apiGroups: [""]
  resources: ["nodes", "nodes/metrics", "services", "endpoints", "pods"]
  verbs: ["get", "list", "watch"]
- apiGroups: ["extensions", "apps"]
  resources: ["deployments", "replicasets"]
  verbs: ["get", "list", "watch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: monitoring-reader
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: monitoring-reader
subjects:
- kind: ServiceAccount
  name: monitoring-reader
  namespace: monitoring
```
#### User Access Management

```bash

# Create user certificate for kubectl access

openssl genrsa -out developer.key 2048
openssl req -new -key developer.key -out developer.csr -subj "/CN=developer/O=developers"
# Sign certificate with cluster CA (on control plane)

sudo openssl x509 -req -in developer.csr -CA /var/lib/rancher/k3s/server/tls/client-ca.crt \
  -CAkey /var/lib/rancher/k3s/server/tls/client-ca.key -out developer.crt -days 365
# Create kubeconfig for user

kubectl config set-credentials developer --client-certificate=developer.crt --client-key=developer.key
kubectl config set-context developer-context --cluster=default --user=developer
```
### ArgoCD Security Configuration

#### RBAC Configuration

```yaml

# ArgoCD RBAC policy

apiVersion: v1
kind: ConfigMap
metadata:
  name: argocd-rbac-cm
  namespace: argocd
data:
  policy.default: role:readonly
  policy.csv: |
    p, role:admin, applications, *, */*, allow
    p, role:admin, clusters, *, *, allow
    p, role:admin, repositories, *, *, allow

    p, role:developer, applications, get, */*, allow
    p, role:developer, applications, sync, */*, allow
    p, role:developer, applications, action/*, */*, allow

    g, admin-group, role:admin
    g, developer-group, role:developer
```
## 🌐 Network Security

### Network Policies

#### Default Deny Policy

```yaml

# Deny all ingress traffic by default

apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-ingress
  namespace: production
spec:
  podSelector: {}
  policyTypes:
  - Ingress
---

# Deny all egress traffic by default

apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-egress
  namespace: production
spec:
  podSelector: {}
  policyTypes:
  - Egress
```
#### Application-Specific Policies

```yaml

# Allow ingress only from ingress controller

apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: web-app-ingress
  namespace: production
spec:
  podSelector:
    matchLabels:
      app: web-app
  policyTypes:
  - Ingress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          name: ingress-nginx
    ports:
    - protocol: TCP
      port: 8080
---

# Allow egress to database only

apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: web-app-egress
  namespace: production
spec:
  podSelector:
    matchLabels:
      app: web-app
  policyTypes:
  - Egress
  egress:
  - to:
    - namespaceSelector:
        matchLabels:
          name: database
    ports:
    - protocol: TCP
      port: 5432
  - to: []
    ports:
    - protocol: TCP
      port: 53
    - protocol: UDP
      port: 53
```
### Ingress Security

#### SSL/TLS Configuration

```yaml

# Secure ingress with cert-manager

apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: secure-app
  annotations:
    cert-manager.io/cluster-issuer: "letsencrypt-prod"
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
    nginx.ingress.kubernetes.io/force-ssl-redirect: "true"
    nginx.ingress.kubernetes.io/hsts: "true"
    nginx.ingress.kubernetes.io/hsts-max-age: "31536000"
    nginx.ingress.kubernetes.io/hsts-include-subdomains: "true"
spec:
  tls:
  - hosts:
    - app.example.com
    secretName: app-tls
  rules:
  - host: app.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: app-service
            port:
              number: 80
```
## 🔒 Container & Pod Security

### Pod Security Standards

#### Restricted Security Context

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: secure-app
spec:
  template:
    spec:
      securityContext:
        runAsNonRoot: true
        runAsUser: 1000
        runAsGroup: 1000
        fsGroup: 1000
        seccompProfile:
          type: RuntimeDefault
      containers:
      - name: app
        image: app:latest
        securityContext:
          allowPrivilegeEscalation: false
          readOnlyRootFilesystem: true
          runAsNonRoot: true
          runAsUser: 1000
          capabilities:
            drop:
            - ALL
        resources:
          limits:
            cpu: 500m
            memory: 512Mi
          requests:
            cpu: 250m
            memory: 256Mi
        volumeMounts:
        - name: tmp
          mountPath: /tmp
        - name: cache
          mountPath: /app/cache
      volumes:
      - name: tmp
        emptyDir: {}
      - name: cache
        emptyDir: {}
```
### Image Security

#### Container Image Scanning

```bash

# Scan images with Trivy

trivy image nginx:alpine
# Scan for high and critical vulnerabilities only

trivy image --severity HIGH,CRITICAL nginx:alpine
# Generate reports

trivy image --format json -o report.json nginx:alpine
```
#### Signed Image Verification

```yaml

# Cosign policy for image verification

apiVersion: v1
kind: ConfigMap
metadata:
  name: cosign-policy
data:
  policy: |
    {
      "default": [
        {
          "type": "signedBy",
          "keyPath": "/etc/cosign/keys/cosign.pub"
        }
      ]
    }
```
## 🗝️ Secrets Management

### Sealed Secrets Implementation

#### Installing Sealed Secrets

```bash

# Install sealed secrets controller

kubectl apply -f https://github.com/bitnami-labs/sealed-secrets/releases/download/v0.24.0/controller.yaml
# Install kubeseal CLI

curl -sSL https://github.com/bitnami-labs/sealed-secrets/releases/download/v0.24.0/kubeseal-0.24.0-linux-amd64.tar.gz | tar xz
sudo install -m 755 kubeseal /usr/local/bin/kubeseal
```
#### Creating and Managing Sealed Secrets

```bash

# Create regular secret

kubectl create secret generic app-secrets \
  --from-literal=database-url=postgresql://user:pass@db:5432/app \
  --from-literal=api-key=secret-api-key \
  --dry-run=client -o yaml > app-secrets.yaml
# Seal the secret

kubeseal -o yaml < app-secrets.yaml > app-sealed-secrets.yaml
# Apply sealed secret

kubectl apply -f app-sealed-secrets.yaml
# Clean up plaintext secret

rm app-secrets.yaml
```
### External Secrets Integration

#### HashiCorp Vault Integration

```yaml

# External secrets operator configuration

apiVersion: external-secrets.io/v1beta1
kind: SecretStore
metadata:
  name: vault-backend
spec:
  provider:
    vault:
      server: "https://vault.example.com"
      path: "secret"
      version: "v2"
      auth:
        kubernetes:
          mountPath: "kubernetes"
          role: "external-secrets"
---
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: app-secrets
spec:
  refreshInterval: 15s
  secretStoreRef:
    name: vault-backend
    kind: SecretStore
  target:
    name: app-secrets
    creationPolicy: Owner
  data:
  - secretKey: database-url
    remoteRef:
      key: app/database
      property: url
  - secretKey: api-key
    remoteRef:
      key: app/api
      property: key
```
## 🔍 Security Monitoring & Logging

### Audit Logging

#### K3s Audit Configuration

```yaml

# /etc/rancher/k3s/audit-policy.yaml

apiVersion: audit.k8s.io/v1
kind: Policy
rules:
- level: Metadata
  namespaces: ["production", "staging"]
  resources:
  - group: ""
    resources: ["secrets", "configmaps"]
- level: RequestResponse
  namespaces: ["production"]
  resources:
  - group: "apps"
    resources: ["deployments", "replicasets"]
  verbs: ["create", "update", "patch", "delete"]
```

```bash

# Start K3s with audit logging

k3s server \
  --audit-log-path=/var/lib/rancher/k3s/server/logs/audit.log \
  --audit-policy-file=/etc/rancher/k3s/audit-policy.yaml \
  --audit-log-maxage=30 \
  --audit-log-maxbackup=10 \
  --audit-log-maxsize=100
```
### Falco Security Monitoring

#### Falco Installation

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: falco
---
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: falco
  namespace: falco
spec:
  selector:
    matchLabels:
      app: falco
  template:
    metadata:
      labels:
        app: falco
    spec:
      serviceAccount: falco
      hostNetwork: true
      hostPID: true
      containers:
      - name: falco
        image: falcosecurity/falco:latest
        securityContext:
          privileged: true
        volumeMounts:
        - name: dev
          mountPath: /host/dev
        - name: proc
          mountPath: /host/proc
          readOnly: true
        - name: boot
          mountPath: /host/boot
          readOnly: true
        - name: lib-modules
          mountPath: /host/lib/modules
          readOnly: true
        - name: usr
          mountPath: /host/usr
          readOnly: true
        - name: etc
          mountPath: /host/etc
          readOnly: true
      volumes:
      - name: dev
        hostPath:
          path: /dev
      - name: proc
        hostPath:
          path: /proc
      - name: boot
        hostPath:
          path: /boot
      - name: lib-modules
        hostPath:
          path: /lib/modules
      - name: usr
        hostPath:
          path: /usr
      - name: etc
        hostPath:
          path: /etc
```
## 🚨 Incident Response

### Security Incident Response Plan

#### Immediate Response (0-1 hour)

1. **Identify and Isolate**
   ```bash
   # Isolate compromised pod
   kubectl label pod suspicious-pod-123 quarantine=true
   kubectl patch networkpolicy default-deny-all -p '{"spec":{"podSelector":{"matchLabels":{"quarantine":"true"}}}}'

   # Scale down compromised deployment
   kubectl scale deployment compromised-app --replicas=0
   ```

2. **Preserve Evidence**
   ```bash
   # Collect logs before they rotate
   kubectl logs compromised-pod-123 > incident-logs-$(date +%Y%m%d-%H%M%S).txt

   # Export pod description
   kubectl describe pod compromised-pod-123 > pod-description-$(date +%Y%m%d-%H%M%S).txt

   # Backup relevant secrets and configs
   kubectl get secret,configmap -o yaml > configs-backup-$(date +%Y%m%d-%H%M%S).yaml
   ```
#### Investigation Phase (1-8 hours)

1. **Log Analysis**
   ```bash
   # Search audit logs for suspicious activity
   grep "user=suspicious" /var/lib/rancher/k3s/server/logs/audit.log

   # Check Falco alerts
   kubectl logs -n falco -l app=falco | grep CRITICAL
   ```

2. **Network Analysis**
   ```bash
   # Check network connections
   kubectl exec suspicious-pod-123 -- netstat -tulpn

   # Analyze network policies
   kubectl get networkpolicy --all-namespaces -o yaml
   ```
#### Recovery Phase (8-24 hours)

1. **Clean Environment**
   ```bash
   # Remove compromised resources
   kubectl delete pod suspicious-pod-123
   kubectl delete deployment compromised-deployment

   # Rotate secrets
   kubeseal --re-encrypt < old-secrets.yaml > new-secrets.yaml
   kubectl apply -f new-secrets.yaml
   ```

2. **Rebuild and Redeploy**
   ```bash
   # Rebuild from clean images
   docker build -t app:secure-$(date +%Y%m%d) .

   # Update deployment with new image
   kubectl set image deployment/app container=app:secure-$(date +%Y%m%d)
   ```
### Security Alerts and Notifications

#### Prometheus Alerting Rules

```yaml
groups:
- name: security
  rules:
  - alert: SuspiciousProcessActivity
    expr: increase(falco_events_total{rule_name="Suspicious Process Activity"}[5m]) > 0
    for: 0m
    labels:
      severity: critical
    annotations:
      summary: "Suspicious process activity detected"
      description: "Falco detected suspicious process activity in {{ $labels.pod }}"

  - alert: UnauthorizedAPICall
    expr: increase(apiserver_audit_total{verb="create",objectRef_resource="pods",user_username!~"system:.*"}[5m]) > 10
    for: 2m
    labels:
      severity: warning
    annotations:
      summary: "High rate of pod creation by user"
      description: "User {{ $labels.user_username }} created {{ $value }} pods in 5 minutes"
```
## 🔧 Security Hardening Checklist

### Node Security

- [ ] **Disable unused services**: `systemctl disable service-name`
- [ ] **Configure firewall**: Allow only necessary ports
- [ ] **Regular updates**: Automated security patches
- [ ] **SSH hardening**: Key-based auth, disable root login
- [ ] **File permissions**: Secure kubeconfig and certificates
- [ ] **Audit logging**: Enable comprehensive audit trails
### Cluster Security

- [ ] **RBAC enabled**: Least privilege access model
- [ ] **Network policies**: Default deny with explicit allows
- [ ] **Pod security standards**: Enforce restricted policies
- [ ] **Admission controllers**: Enable security-focused controllers
- [ ] **API server security**: Secure API server configuration
- [ ] **etcd encryption**: Enable encryption at rest
### Application Security

- [ ] **Image scanning**: Automated vulnerability scanning
- [ ] **Secrets management**: No hardcoded secrets
- [ ] **Network segmentation**: Isolated namespaces
- [ ] **Resource limits**: Prevent resource exhaustion
- [ ] **Security contexts**: Non-root containers
- [ ] **Read-only filesystems**: Prevent tampering
### Operational Security

- [ ] **Monitoring**: Security event monitoring
- [ ] **Backup security**: Encrypted backups
- [ ] **Access logs**: Comprehensive access logging
- [ ] **Incident response**: Documented procedures
- [ ] **Regular audits**: Security posture reviews
- [ ] **Compliance**: Meet regulatory requirements
## 📊 Compliance & Governance

### Security Scanning Schedule

- **Daily**: Container image vulnerability scans
- **Weekly**: Kubernetes configuration scanning
- **Monthly**: Penetration testing
- **Quarterly**: Security audit and review
### Compliance Frameworks

- **CIS Kubernetes Benchmark**: Automated compliance checking
- **NIST Cybersecurity Framework**: Risk assessment and management
- **SOC 2**: Security controls for service organizations
### Documentation Requirements

- **Security policies**: Written and approved policies
- **Incident response plan**: Tested and updated procedures
- **Access control matrix**: Role and permission documentation
- **Change management**: Security review process

---

*Security is an ongoing process, not a one-time setup. Regular reviews, updates, and monitoring are essential for maintaining a secure infrastructure.*
