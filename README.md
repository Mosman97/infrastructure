# IAM Infrastructure

Kubernetes-basiertes Identity and Access Management Setup mit Keycloak.

## Komponenten

- **PostgreSQL**: Datenbank für Keycloak
- **Keycloak Operator**: Kubernetes Operator für Keycloak
- **Keycloak**: Identity & Access Management
- **NGINX Ingress**: Externes Routing

## Deployment

### Mit ArgoCD

```bash
kubectl apply -f argocd/applications/iam-application.yaml
```

### Mit kubectl

```bash
kubectl apply -k deployments/iam
```

## Zugriff

- **Keycloak UI**: http://keycloak.local
- **Username**: admin
- **Password**: admin123

## Voraussetzungen

- Kubernetes Cluster (Docker Desktop, Minikube, etc.)
- ArgoCD (optional)
- NGINX Ingress Controller

## Struktur

```
certificates/          # TLS-Zertifikate
├── keycloak.local.crt
└── keycloak.local.key

argocd/               # GitOps-Konfiguration
├── applications/     # ArgoCD Applications
└── projects/         # ArgoCD Projects

deployments/          # Produktive Deployments
└── iam/             # IAM Stack (Keycloak + PostgreSQL)

operator/            # Keycloak Operator Konfiguration
├── helm-kustomization.yaml
├── secrets-template.yaml
└── values.yaml
```
