# Infrastructure Stack

GitOps-managed Kubernetes infrastructure with ArgoCD, Istio, Keycloak, and Observability.

## Stack

- **GitOps**: ArgoCD with ApplicationSets
- **Service Mesh**: Istio with STRICT mTLS
- **IAM**: Keycloak 26.4.2 + PostgreSQL 18 (CloudNativePG)
- **Observability**: Loki + Grafana + Promtail
- **Security**: NetworkPolicies + Istio mTLS

## Quick Start

### Requirements
- Minikube (16GB RAM, 4 CPUs) or K3s cluster
- kubectl, helm v3+

### Deploy

```bash
# Minikube
minikube start --memory=16384 --cpus=4
./bootstrap/install-argocd.sh
minikube tunnel  # separate terminal

# Add to /etc/hosts
echo "127.0.0.1 argocd.local keycloak.local grafana.local" | sudo tee -a /etc/hosts
```

### Access

**ArgoCD**: http://argocd.local
```bash
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
```

**Keycloak**: http://keycloak.local
```bash
kubectl get secret keycloak-instance-initial-admin -n iam-system -o jsonpath='{.data.password}' | base64 -d
```

**Grafana**: http://grafana.local
```bash
kubectl -n observability get secret grafana-admin-credentials -o jsonpath='{.data.admin-password}' | base64 -d
```

## Structure

```
charts/
├── istio-stack/          # Service mesh
├── istio-gateway/        # Ingress gateway
├── cnpg-operator/        # PostgreSQL operator
├── iam-stack/            # Keycloak + PostgreSQL
└── observability-stack/  # Loki + Grafana
```

## Monitoring

**Keycloak Logs**:
```logql
{namespace="iam-system", pod=~"keycloak-.*"}
```

**PostgreSQL Logs**:
```logql
{namespace="iam-system", pod=~"keycloak-db-.*"}
```
```logql
{namespace="istio-ingress"} |= "GET" | json | method="GET"
```

**All IAM System Logs**:
```logql
{namespace="iam-system"} | json
```

### Metrics & Tracing
- **Istio Prometheus**: Automatic service mesh metrics collection
- **Grafana Dashboards**: Pre-configured for Istio + Loki
- **Distributed Tracing**: Enabled via Istio (Jaeger-compatible headers)

**User Login Events**:
```logql
{namespace="iam-system", pod=~"keycloak-.*"} | json | type="LOGIN"
```

### Data Retention
- **Dev**: No persistence (emptyDir storage)
- **Prod**: 90 days retention policy (configurable)

## 🗂️ Repository Structure

```
infrastructure/
├── argocd/
│   ├── applicationsets/
│   │   └── infrastructure-appset.yaml   # Auto-discovery for all charts
│   └── projects/
│       ├── default-project.yaml
│       ├── iam-project.yaml
│       ├── infrastructure-project.yaml
│       └── observability-project.yaml
├── bootstrap/
│   ├── install-argocd.sh                # Full-stack bootstrap
│   └── cleanup.sh
├── charts/
│   ├── istio-stack/                     # Istio Service Mesh
│   ├── istio-gateway/                   # Ingress Gateway
│   ├── cnpg-operator/                   # PostgreSQL Operator
│   ├── iam-stack/                       # Keycloak + PostgreSQL
│   └── observability-stack/             # Loki + Grafana + Promtail
├── ARCHITECTURE.md                      # Technical architecture docs
└── README.md
```

## ⚙️ Prerequisites

### Minikube (Development)
```bash
minikube start --cpus=4 --memory=16384 --driver=docker
minikube tunnel  # Required for LoadBalancer services
```

### k3s (Production-like)
- **Ingress**: Traefik (pre-installed)
- **Storage**: local-path (pre-installed)
- **Requirements**: 4 CPU cores, 16GB RAM minimum

## 🧹 Cleanup

### Full Stack Removal
```bash
./bootstrap/cleanup.sh
```

### Manual Cleanup
```bash
# Delete all applications
kubectl delete applications -n argocd --all

# Delete namespaces
kubectl delete namespace iam-system observability-system istio-system istio-ingress argocd

# Remove CRDs (optional - removes all CustomResourceDefinitions)
kubectl delete crd $(kubectl get crd | grep 'istio.io\|keycloak.org\|postgresql.cnpg.io' | awk '{print $1}')
```

## 🔐 Security Features

### Istio Service Mesh
- **mTLS**: STRICT mode for all service-to-service communication
- **Port-Level mTLS**: PERMISSIVE on PostgreSQL port 8000 (internal status endpoint only)
- **Authorization Policies**: Namespace-level traffic control
- **Certificate Management**: Automatic rotation via Istio CA

### Application Security
- **Auto-Generated Secrets**: Keycloak Admin, PostgreSQL passwords (Base64 encoded)
- **Security Contexts**: runAsNonRoot, readOnlyRootFilesystem, drop ALL capabilities
- **RBAC**: Least privilege ServiceAccounts for all components
- **Network Policies**: Zero-Trust network segmentation (production)

### Audit & Compliance
- **Audit Logging**: All Keycloak events + PostgreSQL logs captured by Loki
- **Immutable Infrastructure**: GitOps-based deployments with version control
- **Observability**: Full request tracing via Istio distributed tracing headers

## 📚 Ressourcen

- [Keycloak Documentation](https://www.keycloak.org/documentation)
- [Keycloak Operator GitHub](https://github.com/keycloak/keycloak-k8s-resources)
