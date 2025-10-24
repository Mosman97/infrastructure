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
kubectl apply -f apps-argo/iam-stack.yaml
```

### Mit kubectl

```bash
kubectl apply -k apps/iam
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
apps/
├── iam/              # Hauptdeployment (alle Komponenten)
├── keycloak/         # Keycloak Konfiguration
├── keycloak-operator/# Operator Konfiguration
└── postgres/         # PostgreSQL Datenbank

apps-argo/
└── iam-stack.yaml    # ArgoCD Application
```
