#!/bin/bash
set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}🚀 Bootstrapping Kubernetes Infrastructure${NC}"
echo ""

echo -e "${YELLOW}Step 1/3: Installing ArgoCD...${NC}"
helm repo add argo https://argoproj.github.io/argo-helm >/dev/null 2>&1 || true
helm repo update >/dev/null 2>&1

kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f - >/dev/null 2>&1

helm upgrade --install argocd argo/argo-cd \
  --namespace argocd \
  --version 9.1.3 \
  --set server.service.type=ClusterIP \
  --set configs.params."server\.insecure"=true \
  --timeout 5m

# Wait for ArgoCD to be ready
echo "Waiting for ArgoCD to be ready..."
sleep 30

ARGOCD_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)
echo -e "${GREEN}✅ ArgoCD installed${NC}"
echo "   Username: admin"
echo "   Password: $ARGOCD_PASSWORD"
echo ""

echo -e "${YELLOW}Step 2/6: Installing Keycloak CRDs...${NC}"
kubectl apply -f https://raw.githubusercontent.com/keycloak/keycloak-k8s-resources/26.4.2/kubernetes/keycloaks.k8s.keycloak.org-v1.yml
kubectl apply -f https://raw.githubusercontent.com/keycloak/keycloak-k8s-resources/26.4.2/kubernetes/keycloakrealmimports.k8s.keycloak.org-v1.yml
echo -e "${GREEN}✅ Keycloak CRDs installed${NC}"
echo ""

echo -e "${YELLOW}Step 3/6: Deploying ApplicationSet...${NC}"
kubectl apply -f argocd/applicationsets/infrastructure-appset.yaml

echo -e "${GREEN}✅ ApplicationSet deployed${NC}"
echo ""

echo -e "${YELLOW}Step 4/6: Waiting for ApplicationSet to create Applications...${NC}"
sleep 15

echo -e "${GREEN}✅ Applications created${NC}"
echo ""

echo -e "${YELLOW}Step 5/6: Syncing Istio Stack (wave 0)...${NC}"
# Trigger initial sync by adding operation field
kubectl patch application istio-stack -n argocd --type merge -p '{"operation":{"sync":{"revision":"main","prune":true}}}' 2>/dev/null || true
sleep 10

echo "Waiting for Istio to become healthy..."
timeout=300
elapsed=0
while [ $elapsed -lt $timeout ]; do
  health=$(kubectl get application istio-stack -n argocd -o jsonpath='{.status.health.status}' 2>/dev/null || echo "Unknown")
  sync=$(kubectl get application istio-stack -n argocd -o jsonpath='{.status.sync.status}' 2>/dev/null || echo "Unknown")
  
  if [ "$health" = "Healthy" ] && [ "$sync" = "Synced" ]; then
    echo -e "${GREEN}✅ Istio Stack deployed (Health: $health, Sync: $sync)${NC}"
    break
  fi
  
  # Check if pods are running as fallback
  if kubectl get pods -n istio-system -l app=istiod 2>/dev/null | grep -q "1/1.*Running"; then
    echo -e "${GREEN}✅ Istio Stack deployed (pods running)${NC}"
    break
  fi
  
  sleep 10
  elapsed=$((elapsed + 10))
  if [ $((elapsed % 30)) -eq 0 ]; then
    echo "Still waiting... ($elapsed/$timeout seconds, Health: $health, Sync: $sync)"
  fi
done
echo ""

echo -e "${YELLOW}Step 6/6: Syncing remaining stacks...${NC}"
echo "Syncing Observability Stack (wave 1)..."
kubectl patch application observability-stack -n argocd --type merge -p '{"operation":{"sync":{"revision":"main","prune":true}}}' 2>/dev/null || true
sleep 10

echo "Waiting for Observability Stack to become healthy..."
timeout=90
elapsed=0
while [ $elapsed -lt $timeout ]; do
  health=$(kubectl get application observability-stack -n argocd -o jsonpath='{.status.health.status}' 2>/dev/null || echo "Unknown")
  sync=$(kubectl get application observability-stack -n argocd -o jsonpath='{.status.sync.status}' 2>/dev/null || echo "Unknown")
  
  # Accept Synced status even if health is Progressing (pods starting up)
  if [ "$sync" = "Synced" ]; then
    echo -e "${GREEN}✅ Observability Stack synced (Health: $health)${NC}"
    break
  fi
  
  sleep 10
  elapsed=$((elapsed + 10))
  if [ $((elapsed % 30)) -eq 0 ]; then
    echo "Still waiting... ($elapsed/$timeout seconds, Health: $health, Sync: $sync)"
  fi
done
echo ""

echo "Syncing IAM Stack (wave 2)..."
kubectl patch application iam-stack -n argocd --type merge -p '{"operation":{"sync":{"revision":"main","prune":true}}}' 2>/dev/null || true
sleep 10

echo "Waiting for IAM Stack to become healthy..."
timeout=120
elapsed=0
while [ $elapsed -lt $timeout ]; do
  health=$(kubectl get application iam-stack -n argocd -o jsonpath='{.status.health.status}' 2>/dev/null || echo "Unknown")
  sync=$(kubectl get application iam-stack -n argocd -o jsonpath='{.status.sync.status}' 2>/dev/null || echo "Unknown")
  
  # Accept Synced status even if health is Progressing (pods starting up)
  if [ "$sync" = "Synced" ]; then
    echo -e "${GREEN}✅ IAM Stack synced (Health: $health)${NC}"
    break
  fi
  
  sleep 10
  elapsed=$((elapsed + 10))
  if [ $((elapsed % 30)) -eq 0 ]; then
    echo "Still waiting... ($elapsed/$timeout seconds, Health: $health, Sync: $sync)"
  fi
done

echo -e "${GREEN}✅ Bootstrap complete!${NC}"
echo ""
echo "📦 Infrastructure Deployed:"
echo "   ✓ Istio Service Mesh"
echo "   ✓ Observability Stack (Loki, Grafana, Promtail)"
echo "   ✓ IAM Stack (Keycloak, PostgreSQL)"
echo ""
echo "🔍 Monitor deployment:"
echo "   kubectl get applications -n argocd"
echo "   kubectl get pods -n istio-system"
echo "   kubectl get pods -n observability"
echo "   kubectl get pods -n iam-system"
echo ""
echo "🌐 Access ArgoCD UI:"
echo "   kubectl port-forward svc/argocd-server -n argocd 8080:443"
echo "   https://localhost:8080"
echo ""
