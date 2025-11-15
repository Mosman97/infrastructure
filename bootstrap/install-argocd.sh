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
  --version 7.7.12 \
  --set server.service.type=LoadBalancer \
  --set configs.params."server\.insecure"=true \
  --wait \
  --timeout 5m

ARGOCD_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)
echo -e "${GREEN}✅ ArgoCD installed${NC}"
echo "   Username: admin"
echo "   Password: $ARGOCD_PASSWORD"
echo ""

echo -e "${YELLOW}Step 2/3: Deploying ApplicationSet...${NC}"
kubectl apply -f argocd/applicationsets/infrastructure-appset.yaml

echo -e "${GREEN}✅ ApplicationSet deployed${NC}"
echo ""

echo -e "${YELLOW}Step 3/3: Waiting for applications to sync...${NC}"
sleep 10

echo -e "${GREEN}✅ Bootstrap complete!${NC}"
echo ""
echo "📦 ArgoCD will now automatically deploy:"
echo "   - Istio Service Mesh (sync-wave: 0)"
echo "   - Observability Stack (sync-wave: 1)"
echo "   - IAM Stack (sync-wave: 2)"
echo ""
echo "🔍 Monitor deployment:"
echo "   kubectl get applications -n argocd -w"
echo ""
echo "🌐 Access ArgoCD UI:"
echo "   kubectl port-forward svc/argocd-server -n argocd 8080:443"
echo "   https://localhost:8080"
echo ""
