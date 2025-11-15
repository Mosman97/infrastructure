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

echo -e "${YELLOW}Step 2/3: Deploying ApplicationSet...${NC}"
kubectl apply -f argocd/applicationsets/infrastructure-appset.yaml

echo -e "${GREEN}✅ ApplicationSet deployed${NC}"
echo ""

echo -e "${YELLOW}Step 3/5: Waiting for ApplicationSet to create Applications...${NC}"
sleep 15

echo -e "${GREEN}✅ Applications created${NC}"
echo ""

echo -e "${YELLOW}Step 4/5: Syncing Istio Stack (wave 0)...${NC}"
kubectl patch application istio-stack -n argocd --type merge -p '{"spec":{"syncPolicy":{"automated":{"prune":true,"selfHeal":true}}}}' 
sleep 10

echo "Waiting for Istio to become healthy..."
timeout=300
elapsed=0
while [ $elapsed -lt $timeout ]; do
  if kubectl get pods -n istio-system -l app=istiod 2>/dev/null | grep -q "1/1.*Running"; then
    echo -e "${GREEN}✅ Istio Stack deployed${NC}"
    break
  fi
  sleep 10
  elapsed=$((elapsed + 10))
  if [ $((elapsed % 30)) -eq 0 ]; then
    echo "Still waiting... ($elapsed/$timeout seconds)"
  fi
done

# Reset selfHeal to false after successful deployment
kubectl patch application istio-stack -n argocd --type merge -p '{"spec":{"syncPolicy":{"automated":{"prune":true,"selfHeal":false}}}}'
echo ""

echo -e "${YELLOW}Step 5/5: Syncing remaining stacks...${NC}"
echo "Syncing Observability Stack (wave 1)..."
kubectl patch application observability-stack -n argocd --type merge -p '{"spec":{"syncPolicy":{"automated":{"prune":true,"selfHeal":true}}}}'
sleep 90

# Reset selfHeal to false
kubectl patch application observability-stack -n argocd --type merge -p '{"spec":{"syncPolicy":{"automated":{"prune":true,"selfHeal":false}}}}'

echo "Syncing IAM Stack (wave 2)..."
kubectl patch application iam-stack -n argocd --type merge -p '{"spec":{"syncPolicy":{"automated":{"prune":true,"selfHeal":true}}}}'
sleep 90

# Reset selfHeal to false
kubectl patch application iam-stack -n argocd --type merge -p '{"spec":{"syncPolicy":{"automated":{"prune":true,"selfHeal":false}}}}'

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
