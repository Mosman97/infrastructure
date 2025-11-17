# Infrastructure Stack

GitOps-managed Kubernetes infrastructure with ArgoCD, Istio Service Mesh, Keycloak IAM, and Observability.

## 🏗️ Architecture

- **Service Mesh**: Istio 1.24+ with STRICT mTLS
- **IAM**: Keycloak 26.4.2 with PostgreSQL 18 (CNPG)
- **Observability**: Loki + Grafana + Promtail
- **GitOps**: ArgoCD with ApplicationSets
- **Ingress**: Istio Gateway (auto-injected)

## 🚀 Schnellstart

### Voraussetzungen
- **Minikube**: 16GB RAM, 4 CPUs empfohlen
- **kubectl**: Latest version
- **helm**: v3+

### Bootstrap (Full Stack Deployment)
```bash
# Minikube starten
minikube start --memory=16384 --cpus=4

# Bootstrap ausführen (installiert alles)
./bootstrap/install-argocd.sh

# Minikube tunnel für LoadBalancer (neues Terminal)
minikube tunnel

# Status prüfen
kubectl get applications -n argocd
```

**Das Bootstrap-Script installiert:**
1. ArgoCD + Initial Admin Secret
2. Keycloak & CNPG CRDs
3. ArgoCD Projects (iam, infrastructure, observability)
4. ApplicationSet (deployed alle Charts automatisch)
5. Istio Stack (Service Mesh mit mTLS)
6. Istio Gateway (mit Injection-Wait-Logic)
7. CNPG Operator (PostgreSQL Management)
8. Observability Stack (Loki, Grafana, Promtail)
9. IAM Stack (Keycloak + PostgreSQL Cluster)

## 🔐 Zugriff auf Services

### ArgoCD UI
**URL**: http://argocd.local

```bash
# Admin Password abrufen
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
```

### Keycloak Admin Console
**URL**: http://keycloak.local

```bash
# Admin Credentials abrufen
echo "Username: $(kubectl get secret keycloak-instance-initial-admin -n iam-system -o jsonpath='{.data.username}' | base64 -d)"
echo "Password: $(kubectl get secret keycloak-instance-initial-admin -n iam-system -o jsonpath='{.data.password}' | base64 -d)"
```

### Grafana Dashboards
**URL**: http://grafana.local

**Default Login**: admin / (aus Secret)
```bash
kubectl -n observability get secret grafana-admin-credentials -o jsonpath='{.data.admin-password}' | base64 -d
```

⚠️ **Wichtig**: `/etc/hosts` Einträge erforderlich:
```bash
echo "127.0.0.1 argocd.local keycloak.local grafana.local" | sudo tee -a /etc/hosts
```

## 📦 Komponenten

### Istio Stack (Service Mesh)
- **Istio Base**: CRDs and core components
- **Istiod**: Control plane (Gateway injection, mTLS CA)
- **Istio Gateway**: Ingress gateway with automatic sidecar injection
- **mTLS**: STRICT mode for all service-to-service communication

### IAM Stack
- **PostgreSQL 18**: 3-Node-Cluster mit CloudNativePG
  - STRICT mTLS mit Port 8000 PERMISSIVE (für CNPG Operator Status)
- **Keycloak 26.4.2**: 1 Replica (dev), 2 Replicas (prod)
- **Keycloak Operator 26.4.2**: CRD Management
- **CNPG Operator**: PostgreSQL Cluster Management (ohne Istio Sidecar)

### Observability Stack
- **Loki 3.5.7**: SingleBinary mode, Filesystem storage
- **Promtail**: Log collector (DaemonSet)
- **Grafana 12.2.1**: Dashboards & Queries
- **Loki Canary**: Health monitoring

## 🔄 GitOps Workflow

### ApplicationSet Pattern
Alle Stacks werden über ein **ApplicationSet** verwaltet:
```yaml
charts/
├── istio-stack/
├── istio-gateway/
├── cnpg-operator/
├── iam-stack/
└── observability-stack/
```

**Auto-Discovery**: ApplicationSet generiert automatisch eine Application pro Chart-Verzeichnis.

### Deployment-Reihenfolge (Bootstrap)
1. **Wave 1**: Istio Stack deployment
2. **Wait**: Istiod ready + Sidecar Injection verfügbar
3. **Wave 2**: Istio Gateway deployment (mit Injection-Check)
4. **Wave 3**: CNPG Operator
5. **Wave 4**: Parallel deployment von IAM & Observability Stacks

### Sync Policy
- **Automated Sync**: Enabled mit Prune
- **Self-Heal**: Disabled (manuelle Kontrolle)
- **Retry Logic**: 5 attempts mit exponential backoff (5s → 3m)

### Health Checks & Workarounds
**PostgreSQL Cluster**: 
- Status Extraction Error aufgrund Istio mTLS + CNPG Operator
- Lösung: Port 8000 auf PERMISSIVE, Operator ohne Sidecar
- Cluster ist functional trotz "Progressing" Status

## 📊 Observability & Monitoring

### Logging Pipeline
**Promtail** (DaemonSet) → **Loki** (SingleBinary) → **Grafana** (Dashboard)

### Log Queries (LogQL)

**Keycloak Events**:
```logql
{namespace="iam-system", pod=~"keycloak-.*"} |= "type" | json
```

**PostgreSQL Logs**:
```logql
{namespace="iam-system", pod=~"keycloak-db-.*"} |= "LOG:"
```

**Istio Access Logs**:
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
