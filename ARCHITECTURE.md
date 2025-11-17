# Architecture

## Overview

```
Client → Istio Gateway (mTLS) → Services
                               ├─ Keycloak → PostgreSQL
                               ├─ Grafana → Loki
                               └─ ArgoCD
```

## Components

### Service Mesh (Istio)
- **Gateway**: LoadBalancer ingress
- **Istiod**: Control plane, mTLS CA, sidecar injection
- **mTLS**: STRICT mode (all traffic encrypted)

### IAM (iam-system namespace)
- **Keycloak**: Identity provider (1 replica dev, 2 prod)
- **PostgreSQL**: 3-node cluster (CloudNativePG)
- **CNPG Operator**: Database management (no sidecar)

### Observability (observability namespace)
- **Loki**: Log aggregation (SingleBinary)
- **Grafana**: Dashboards and queries
- **Promtail**: DaemonSet log collector

### GitOps
- **ArgoCD**: ApplicationSet auto-discovers charts
- **Sync**: Automated with prune, 5 retries

## mTLS Configuration

**STRICT Mode**: All service traffic encrypted (ports 5432, 3100, 8080, 3000)

**PERMISSIVE Mode (Port 8000 only)**:
- CNPG operator checks PostgreSQL health on port 8000
- Operator has no Istio sidecar (can't do mTLS)
- Port 8000 is internal-only, not exposed externally
- SQL traffic on port 5432 remains STRICT mTLS

**Risk**: Port 8000 accepts plain HTTP from any pod in cluster
**Mitigation**: NetworkPolicies whitelist only CNPG operator access

## Data Flow

### User Authentication
```
Browser → Gateway → Keycloak → PostgreSQL
```

### Logging
```
Apps → Promtail → Loki → Grafana
```

### GitOps
```
Git Push → ArgoCD → Kubernetes
```

### GitOps Deployment Flow
1. **Git Commit**: Developer pushes to infrastructure repository
2. **ArgoCD Sync**: ApplicationSet detects changes, triggers sync
3. **Bootstrap Wave 1-4**: Istio → Gateway → CNPG → IAM/Observability
4. **Health Check**: ArgoCD validates pod health, service availability
5. **Status Update**: Applications marked as Synced/Healthy in ArgoCD UI

### Certificate Management
1. **Istiod CA**: Issues mTLS certificates for all sidecar-injected pods
2. **Automatic Rotation**: Certificates rotated every 24 hours (default)
3. **Mutual Authentication**: All service-to-service communication encrypted + authenticated


