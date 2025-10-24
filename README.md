# IAM Infrastructure

Kubernetes-basiertes Identity and Access Management mit Keycloak.

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

⚠️ Wichtig: `/etc/hosts` Eintrag erforderlich:
```bash
echo "127.0.0.1 keycloak.local" | sudo tee -a /etc/hosts
```

### Admin-Credentials abrufen

Das initiale Admin-Passwort wird automatisch generiert. So erhältst du es:

```bash
# Passwort anzeigen
kubectl get secret keycloak-instance-initial-admin \
  -n iam-system \
  -o jsonpath='{.data.password}' | base64 -d

# Username anzeigen (meist 'admin')
kubectl get secret keycloak-instance-initial-admin \
  -n iam-system \
  -o jsonpath='{.data.username}' | base64 -d
```

**Oder komplett:**
```bash
echo "Username: $(kubectl get secret keycloak-instance-initial-admin -n iam-system -o jsonpath='{.data.username}' | base64 -d)"
echo "Password: $(kubectl get secret keycloak-instance-initial-admin -n iam-system -o jsonpath='{.data.password}' | base64 -d)"
```

## 📦 Komponenten

- **PostgreSQL 15**: Persistente Datenbank für Keycloak
- **Keycloak Operator**: Kubernetes Operator (v26.0.0)
- **Keycloak**: Identity & Access Management
- **NGINX Ingress**: HTTP-Routing

## 🏗️ Deployment-Optionen

### Option 1: Mit kubectl/kustomize (empfohlen)

```bash
kubectl apply -k deployments/iam
```

### Option 2: Mit ArgoCD

```bash
# ArgoCD Project erstellen
kubectl apply -f argocd/projects/iam-project.yaml

# Application deployen
kubectl apply -f argocd/applications/iam-application.yaml
```

## 🔍 Troubleshooting

### Pods prüfen
```bash
kubectl get pods -n iam-system
kubectl logs -n iam-system deployment/keycloak-operator
kubectl logs -n iam-system statefulset/keycloak-instance
```

### Keycloak Status
```bash
kubectl get keycloak -n iam-system
kubectl describe keycloak keycloak-instance -n iam-system
```

### Ingress prüfen
```bash
kubectl get ingress -n iam-system
curl -v http://keycloak.local
```

### Häufige Probleme

**Problem**: `no matches for kind "Keycloak"`
```bash
# Operator neu installieren
kubectl apply -f https://raw.githubusercontent.com/keycloak/keycloak-k8s-resources/26.0.0/kubernetes/kubernetes.yml
```

**Problem**: PostgreSQL startet nicht
```bash
# PVC prüfen
kubectl get pvc -n iam-system
kubectl describe pvc postgres-storage-postgresql-db-0 -n iam-system
```

**Problem**: Keycloak nicht erreichbar
```bash
# Service prüfen
kubectl get svc -n iam-system
kubectl port-forward svc/keycloak-instance-service 8080:8080 -n iam-system
# Dann: http://localhost:8080
```

## 🗂️ Projekt-Struktur

```
infrastructure/
├── README.md
├── .gitignore
│
├── certificates/              # TLS-Zertifikate (gitignored)
│   ├── keycloak.local.crt
│   └── keycloak.local.key
│
├── argocd/                    # GitOps-Konfiguration
│   ├── projects/
│   │   └── iam-project.yaml
│   └── applications/
│       └── iam-application.yaml
│
└── deployments/               # Kubernetes Manifests
    └── iam/
        ├── kustomization.yaml          # Kustomize Orchestrierung
        ├── database-postgres.yaml      # PostgreSQL StatefulSet + Service
        ├── secrets-credentials.yaml    # DB Credentials
        ├── keycloak-instance.yaml      # Keycloak Custom Resource
        └── ingress-keycloak.yaml       # NGINX Ingress
```

## ⚙️ Voraussetzungen

- Kubernetes Cluster (Docker Desktop, Minikube, Kind, etc.)
- `kubectl` CLI installiert
- NGINX Ingress Controller:
  ```bash
  kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.8.1/deploy/static/provider/cloud/deploy.yaml
  ```

## 🧹 Cleanup

```bash
# Kompletten Stack löschen
kubectl delete namespace iam-system

# Nur Keycloak löschen (DB bleibt)
kubectl delete keycloak keycloak-instance -n iam-system
```

## 🔐 Sicherheitshinweise

⚠️ **Nicht für Produktion geeignet!**

Diese Konfiguration ist für Entwicklung/Testing gedacht:
- Hardcodierte Passwörter in Secrets
- Keine TLS-Verschlüsselung
- `strict: false` bei Hostname-Checks
- Keine Resource Limits
- Single Replica (nicht hochverfügbar)

Für Produktion siehe: [Keycloak Production Guide](https://www.keycloak.org/server/configuration-production)

## 📚 Weitere Ressourcen

- [Keycloak Documentation](https://www.keycloak.org/documentation)
- [Keycloak Operator GitHub](https://github.com/keycloak/keycloak-k8s-resources)
- [Kubernetes Ingress](https://kubernetes.io/docs/concepts/services-networking/ingress/)
