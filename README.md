# Kubernetes Infrastructure mit GitOps

GitOps-basierte Kubernetes-Infrastruktur mit ArgoCD, Istio Service Mesh, Keycloak IAM und Observability Stack.

## 🎯 Was ist das?

Produktionsreife Kubernetes-Infrastruktur die automatisch deployt:
- **ArgoCD** - GitOps Controller (alles aus Git)
- **Istio** - Service Mesh mit automatischer mTLS-Verschlüsselung
- **Keycloak** - Identity & Access Management (SSO, OAuth2, OIDC)
- **PostgreSQL** - Hochverfügbare Datenbank (CNPG Operator, 3 Instances)
- **Loki + Grafana** - Logging und Monitoring

**Umgebungen:**
- `values-dev.yaml` - Minikube (1 Replica, 16GB RAM, weniger Resources)
- `values-k8s.yaml` - Production (HA, mehr Resources, TLS, LoadBalancer)

---

## 🚀 Quick Start

### Voraussetzungen

```bash
# Minikube
minikube start --cpus=4 --memory=16384 --driver=docker

# Oder K3s / vanilla K8s Cluster
```

### Installation (1 Command)

```bash
git clone https://github.com/Mosman97/infrastructure.git
cd infrastructure

./bootstrap/install-argocd.sh
```

**Was passiert:**
1. ArgoCD installiert (Helm Chart)
2. ArgoCD Projects erstellt (iam, observability, infrastructure)
3. ApplicationSets deployen alle Stacks automatisch
4. Warten auf Sync (5-10 Minuten)

### Zugriff auf UIs

```bash
# /etc/hosts erweitern (Minikube)
echo "127.0.0.1 argocd.local keycloak.local grafana.local" | sudo tee -a /etc/hosts

# Port-Forwards starten
kubectl port-forward svc/argocd-server -n argocd 8080:443 &
kubectl port-forward svc/keycloak-service -n iam-system 8443:8080 &
kubectl port-forward svc/observability-stack-grafana -n observability-system 3000:80 &
```

**URLs:**
- ArgoCD: https://localhost:8080
- Keycloak: http://localhost:8443
- Grafana: http://localhost:3000

---

## 🔑 Passwörter

### ArgoCD
```bash
# Username: admin
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d && echo
```

### Keycloak
```bash
# Username: admin
kubectl get secret keycloak-initial-admin -n iam-system \
  -o jsonpath='{.data.password}' | base64 -d && echo
```

### Grafana (nur Dev)
```bash
# Username: admin
# Password: admin
```

**Production:** Keine hardcoded Secrets! Nutze Sealed Secrets oder External Secrets Operator.

---

## 📦 Was wird installiert?

| Component | Version | Namespace | Replicas (dev/k8s) | Beschreibung |
|-----------|---------|-----------|-------------------|--------------|
| ArgoCD | 9.1.3 | argocd | 1/3 | GitOps Controller |
| Istio | 1.28.0 | istio-system | - | Service Mesh (mTLS) |
| Istio Gateway | 1.28.0 | istio-ingress | 1/2-5 (HPA) | TLS Termination |
| Keycloak | 26.4.2 | iam-system | 1/2 | SSO / OAuth2 / OIDC |
| PostgreSQL | 18 | iam-system | 1/3 | CNPG Cluster |
| Loki | 3.5.7 | observability-system | 1/1 | Log Aggregation |
| Promtail | - | observability-system | DaemonSet | Log Shipper |
| Grafana | 12.2.1 | observability-system | 1/2 | Dashboards |

---

## 🔧 Konfiguration

### Dev vs Production

**Dev (Minikube):**
```yaml
storageClass: standard  # Minikube default
ingress: false  # Port-Forward
replicas: 1
resources: 256Mi/500m
```

**Production (K8s):**
```yaml
storageClass: gp3 / managed-premium / longhorn / nfs-client
gateway: true  # Istio Gateway + TLS
replicas: 2-3
resources: 1Gi/1 CPU
```

### Hostnames anpassen

**Dev:**
- argocd.local
- keycloak.local
- grafana.local

**Production** (`charts/istio-gateway/values-k8s.yaml`):
```yaml
hosts: ["*.yourdomain.com"]
virtualServices:
  keycloak:
    host: "keycloak.yourdomain.com"
  grafana:
    host: "grafana.yourdomain.com"
```

### Resources anpassen

```yaml
# charts/iam-stack/values-dev.yaml
keycloak:
  resources:
    requests:
      memory: "512Mi"  # Erhöhen wenn OOMKilled
      cpu: "500m"
```

---

## 🏗️ Production Setup

### 1. StorageClass

**Cloud (AWS/Azure/GCP):**
```yaml
# Automatisch verfügbar
storageClass: ""  # = Default (gp3 / managed-premium / standard)
```

**On-Premise:**

**Option A: Longhorn (empfohlen für HA)**
```bash
helm repo add longhorn https://charts.longhorn.io
helm install longhorn longhorn/longhorn -n longhorn-system --create-namespace
# → storageClass: longhorn
```

**Option B: NFS (einfach, kein HA)**
```bash
helm repo add nfs-subdir-external-provisioner \
  https://kubernetes-sigs.github.io/nfs-subdir-external-provisioner
helm install nfs-provisioner nfs-subdir-external-provisioner/nfs-subdir-external-provisioner \
  --set nfs.server=192.168.1.10 \
  --set nfs.path=/export/k8s \
  --set storageClass.name=nfs-client \
  -n kube-system
# → storageClass: nfs-client
```

### 2. TLS-Zertifikate

**Option A: Let's Encrypt (automatisch)**
```bash
# cert-manager installieren
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.16.3/cert-manager.yaml

# ClusterIssuer
cat <<EOF | kubectl apply -f -
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: admin@yourdomain.com  # ANPASSEN
    privateKeySecretRef:
      name: letsencrypt-prod
    solvers:
    - http01:
        ingress:
          class: istio
EOF

# Certificate
cat <<EOF | kubectl apply -f -
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: wildcard-tls-cert
  namespace: istio-ingress
spec:
  secretName: wildcard-tls-cert
  issuerRef:
    name: letsencrypt-prod
    kind: ClusterIssuer
  dnsNames:
  - "*.yourdomain.com"
EOF
```

**Option B: Eigene PKI (Firmen-CA)**
```bash
kubectl create secret tls wildcard-tls-cert \
  --cert=fullchain.pem \
  --key=privkey.pem \
  -n istio-ingress
```

### 3. DNS

```bash
# LoadBalancer IP holen
kubectl get svc -n istio-ingress

# A-Records erstellen:
# *.yourdomain.com  A  <EXTERNAL-IP>
# Oder einzeln:
# keycloak.yourdomain.com  A  <EXTERNAL-IP>
# grafana.yourdomain.com   A  <EXTERNAL-IP>
```

### 4. Secrets Management

**Sealed Secrets (empfohlen):**
```bash
helm repo add sealed-secrets https://bitnami-labs.github.io/sealed-secrets
helm install sealed-secrets sealed-secrets/sealed-secrets -n kube-system

# Secret verschlüsseln
kubectl create secret generic db-password --from-literal=password=xyz123 \
  --dry-run=client -o yaml | \
  kubeseal -o yaml > db-password-sealed.yaml

# In Git committen (verschlüsselt!)
git add db-password-sealed.yaml
```

**External Secrets Operator:**
```bash
helm repo add external-secrets https://charts.external-secrets.io
helm install external-secrets external-secrets/external-secrets \
  -n external-secrets-system --create-namespace

# Nutze AWS Secrets Manager / HashiCorp Vault / etc.
```

### 5. Backups

**PostgreSQL zu S3/MinIO:**
```yaml
# charts/iam-stack/values-k8s.yaml
postgres:
  backup:
    enabled: true
    destinationPath: "s3://my-bucket/postgres-backups"
    s3Credentials:
      accessKeyId: "..."
      secretAccessKey: "..."
      region: "eu-central-1"
    retentionPolicy: "30d"
```

**Volume Snapshots:**
```bash
# Mit Velero
helm install velero vmware-tanzu/velero \
  --set configuration.backupStorageLocation[0].bucket=my-backups \
  --set configuration.volumeSnapshotLocation[0].config.region=eu-central-1
```

---

## 🐛 Troubleshooting

### ArgoCD App nicht Synced

```bash
# Status anschauen
kubectl get app -n argocd

# Details + Fehlermeldung
kubectl describe app <name> -n argocd

# Manual Sync
kubectl patch app <name> -n argocd --type merge -p '{"metadata":{"annotations":{"argocd.argoproj.io/refresh":"hard"}}}'
```

### Pod crasht mit OOMKilled

```bash
# Events checken
kubectl get events -n <namespace> --sort-by='.lastTimestamp'

# Resource Usage
kubectl top pod -n <namespace>

# → Resources erhöhen in values.yaml
```

### NetworkPolicy blockiert Traffic

```bash
# Temporär testen ohne NetworkPolicy
kubectl delete netpol <name> -n <namespace>

# Debug-Pod starten
kubectl run -it --rm debug --image=nicolaka/netshoot -- /bin/bash
curl http://service-name.namespace.svc.cluster.local:8080
```

### Loki zeigt keine Logs

```bash
# Promtail läuft?
kubectl get ds promtail -n observability-system

# Promtail Logs
kubectl logs -n observability-system ds/observability-stack-promtail

# Loki erreichbar?
kubectl run -it --rm curl --image=curlimages/curl -- \
  curl http://observability-stack-loki.observability-system.svc:3100/ready
```

### Keycloak DB Connection Error

```bash
# PostgreSQL läuft?
kubectl get cluster -n iam-system

# Instances ready?
kubectl get pod -n iam-system -l cnpg.io/cluster=keycloak-db

# Connection testen
kubectl run -it --rm psql --image=postgres:18 -- \
  psql -h keycloak-db-rw.iam-system.svc -U postgres -d keycloak
```

---

## 🧹 Cleanup

```bash
./bootstrap/cleanup.sh

# Oder manuell:
kubectl delete applicationset infrastructure-appset -n argocd
kubectl delete applications --all -n argocd
helm uninstall argocd -n argocd
kubectl delete ns argocd iam-system observability-system istio-system istio-ingress
```

---

## 📚 Weiterführende Docs

- [ArgoCD Docs](https://argo-cd.readthedocs.io/)
- [Istio Docs](https://istio.io/latest/docs/)
- [Keycloak Docs](https://www.keycloak.org/documentation)
- [CNPG Docs](https://cloudnative-pg.io/)
- [Loki Docs](https://grafana.com/docs/loki/latest/)

---

## 🤝 Contributing

1. Fork repo
2. Feature-Branch erstellen
3. Änderungen committen
4. PR erstellen

---

## 📄 Lizenz

MIT - siehe LICENSE
