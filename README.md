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
# Password: GrafanaAdminPassword123
# (wird als Secret grafana-admin-credentials/admin-password im Namespace observability-system erzeugt)
```



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

**Empfohlene Optionen:**
- Longhorn (replizierter Block-Storage, HA)
- NFS (einfach, kein HA)
- Standard StorageClass des Clusters

Beispiel für Longhorn:
```bash
helm repo add longhorn https://charts.longhorn.io
helm install longhorn longhorn/longhorn -n longhorn-system --create-namespace
# → storageClass: longhorn
```

Beispiel für NFS:
```bash
helm repo add nfs-subdir-external-provisioner https://kubernetes-sigs.github.io/nfs-subdir-external-provisioner
helm install nfs-provisioner nfs-subdir-external-provisioner/nfs-subdir-external-provisioner \
  --set nfs.server=192.168.1.10 \
  --set nfs.path=/export/k8s \
  --set storageClass.name=nfs-client \
  -n kube-system
# → storageClass: nfs-client
```

### 2. TLS-Zertifikate




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

Für produktive Umgebungen empfiehlt sich ein Tool wie Sealed Secrets oder External Secrets Operator, um sensible Daten sicher im Cluster zu verwalten.

### 5. Backups


**Backups:**
Backup-Lösungen wie Velero oder S3/MinIO können für Datenbank- und Volume-Backups genutzt werden. Details siehe jeweilige Tool-Dokumentation.

---


