# IAM Infrastructure

Kubernetes-basiertes Identity and Access Management mit Keycloak 26.4.2.

## 🚀 Schnellstart

```bash
# Namespace erstellen
kubectl create namespace iam-system

# Stack deployen
kubectl apply -k deployments/iam

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

- **PostgreSQL 18**: Persistente Datenbank
- **Keycloak 26.4.2**: Identity & Access Management (2 Replicas)
- **Keycloak Operator 26.4.2**: Kubernetes Operator
- **NGINX Ingress**: HTTP-Routing

## 🏗️ Deployment-Optionen

### kubectl/kustomize
```bash
kubectl apply -k deployments/iam
```

### ArgoCD
```bash
kubectl apply -f argocd/projects/iam-project.yaml
kubectl apply -f argocd/applications/iam-application.yaml
```

## 🗂️ Struktur

```
infrastructure/
├── deployments/iam/
│   ├── kustomization.yaml
│   ├── database-postgres.yaml
│   ├── secrets-credentials.yaml
│   ├── keycloak-instance.yaml
│   └── ingress-keycloak.yaml
└── argocd/
    ├── projects/iam-project.yaml
    └── applications/iam-application.yaml
```

## ⚙️ Voraussetzungen

- Kubernetes Cluster
- kubectl CLI
- NGINX Ingress Controller:
  ```bash
  kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.8.1/deploy/static/provider/cloud/deploy.yaml
  ```

## 🧹 Cleanup

```bash
kubectl delete namespace iam-system
```

## 🔐 Hinweis

⚠️ Diese Konfiguration ist für **Entwicklung/Testing** gedacht, nicht für Produktion.

## 📚 Ressourcen

- [Keycloak Documentation](https://www.keycloak.org/documentation)
- [Keycloak Operator GitHub](https://github.com/keycloak/keycloak-k8s-resources)
