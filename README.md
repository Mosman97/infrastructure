# IAM Infrastructure

Kubernetes-basiertes Identity and Access Management mit Keycloak 26.4.2.

## 🚀 Schnellstart

### Operatoren installieren
```bash
# CloudNativePG Operator
kubectl apply -f https://raw.githubusercontent.com/cloudnative-pg/cloudnative-pg/release-1.21/releases/cnpg-1.21.0.yaml

# Keycloak Operator
kubectl apply -f https://raw.githubusercontent.com/keycloak/keycloak-k8s-resources/26.4.2/kubernetes/keycloaks.k8s.keycloak.org-v1.yml
kubectl apply -f https://raw.githubusercontent.com/keycloak/keycloak-k8s-resources/26.4.2/kubernetes/keycloakrealmimports.k8s.keycloak.org-v1.yml
kubectl apply -f https://raw.githubusercontent.com/keycloak/keycloak-k8s-resources/26.4.2/kubernetes/kubernetes.yml
```

### IAM Stack deployen
```bash
kubectl create namespace iam-system

# Docker Desktop (dev)
helm install iam-stack charts/iam-stack -f charts/iam-stack/values-dev.yaml -n iam-system

# k3s (prod)
helm install iam-stack charts/iam-stack -f charts/iam-stack/values-k3s.yaml -n iam-system

# Status prüfen
kubectl get pods -n iam-system -w
```

## 🔑 Zugriff auf Keycloak

### URL
**http://keycloak.local**

⚠️ **Wichtig**: `/etc/hosts` Eintrag erforderlich:
```bash
echo "127.0.0.1 keycloak.local" | sudo tee -a /etc/hosts
```

### Admin-Credentials abrufen

```bash
echo "Username: $(kubectl get secret keycloak-instance-initial-admin -n iam-system -o jsonpath='{.data.username}' | base64 -d)"
echo "Password: $(kubectl get secret keycloak-instance-initial-admin -n iam-system -o jsonpath='{.data.password}' | base64 -d)"
```

## 📦 Komponenten

### IAM Stack
- **PostgreSQL 18**: 3-Node-Cluster mit CloudNativePG
- **Keycloak 26.4.2**: 2 Replicas mit Autoinit-Job
- **Keycloak Operator 26.4.2**: CRD Management
- **Network Policies**: Zero-Trust Networking

### Observability Stack
- **Loki**: Zentrales Log-Management (1 Jahr Retention)
- **Promtail**: Log-Collector (DaemonSet)
- **Grafana**: Dashboards & Queries

## 🏗️ Deployment mit ArgoCD

### IAM Stack
```bash
kubectl apply -f argocd/projects/iam-project.yaml
kubectl apply -f argocd/applications/iam-application.yaml
```

### Observability Stack
```bash
kubectl apply -f argocd/projects/observability-project.yaml
kubectl apply -f argocd/applications/observability-application.yaml
```

## 📊 Observability & Audit Logging

### Loki Stack deployen
```bash
kubectl create namespace observability
kubectl apply -f argocd/projects/observability-project.yaml
kubectl apply -f argocd/applications/observability-application.yaml
```

### Grafana Zugriff
**URL**: http://grafana.local

`/etc/hosts` Eintrag erforderlich:
```bash
echo "127.0.0.1 grafana.local" | sudo tee -a /etc/hosts
```

**Login**: admin / admin123

### Audit Logs prüfen

**Keycloak Events (LogQL)**:
```logql
{namespace="iam-system", app="keycloak"} |= "type" | json
```

**PostgreSQL Audit Logs**:
```logql
{namespace="iam-system", app="keycloak-db"} |= "LOG:" | json
```

**User-Login-Events**:
```logql
{namespace="iam-system", app="keycloak"} | json | type="LOGIN"
```

**Datenaufbewahrung**: 1 Jahr (8760 Stunden)

## 🗂️ Struktur

```
infrastructure/
├── charts/iam-stack/
│   ├── templates/
│   ├── values-dev.yaml
│   └── values-k3s.yaml
└── argocd/
    ├── projects/
    │   ├── iam-project.yaml
    │   └── observability-project.yaml
    └── applications/
        ├── iam-application.yaml
        └── observability-application.yaml
```

## ⚙️ Voraussetzungen

### Docker Desktop
- NGINX Ingress Controller
- StorageClass: hostpath

### k3s
- Traefik Ingress (vorinstalliert)
- StorageClass: local-path (vorinstalliert)

## 🧹 Cleanup

```bash
kubectl delete namespace iam-system
kubectl delete namespace observability
```

## 🔐 Security Features

- Auto-generierte Secrets (Keycloak Admin, PostgreSQL)
- Network Policies für Zero-Trust
- Security Contexts (runAsNonRoot, drop ALL capabilities)
- RBAC mit Least Privilege
- Audit Logging für Compliance

## 📚 Ressourcen

- [Keycloak Documentation](https://www.keycloak.org/documentation)
- [Keycloak Operator GitHub](https://github.com/keycloak/keycloak-k8s-resources)
