#!/bin/bash
set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}🚀 Bootstrapping Infrastructure${NC}\n"

echo -e "${YELLOW}[1/4] Installing ArgoCD...${NC}"
helm repo add argo https://argoproj.github.io/argo-helm >/dev/null 2>&1 || true
helm repo update >/dev/null 2>&1
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f - >/dev/null 2>&1
helm upgrade --install argocd argo/argo-cd \
  --namespace argocd \
  --version 9.1.3 \
  --set server.service.type=ClusterIP \
  --set configs.params."server\.insecure"=true \
  --timeout 5m >/dev/null
sleep 30
ARGOCD_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)
echo -e "${GREEN}✅ ArgoCD ready (admin:$ARGOCD_PASSWORD)${NC}\n"

echo -e "${YELLOW}[2/4] Installing Keycloak CRDs...${NC}"
kubectl apply -f https://raw.githubusercontent.com/keycloak/keycloak-k8s-resources/26.4.2/kubernetes/keycloaks.k8s.keycloak.org-v1.yml >/dev/null
kubectl apply -f https://raw.githubusercontent.com/keycloak/keycloak-k8s-resources/26.4.2/kubernetes/keycloakrealmimports.k8s.keycloak.org-v1.yml >/dev/null
echo -e "${GREEN}✅ CRDs installed${NC}\n"

echo -e "${YELLOW}[3/4] Deploying ApplicationSet...${NC}"
kubectl apply -f argocd/applicationsets/infrastructure-appset.yaml >/dev/null
sleep 10
echo -e "${GREEN}✅ ApplicationSet deployed${NC}\n"

echo -e "${YELLOW}[4/4] Triggering initial sync...${NC}"
kubectl patch application istio-stack -n argocd --type merge -p '{"operation":{"sync":{"prune":true}}}' 2>/dev/null || true
kubectl patch application observability-stack -n argocd --type merge -p '{"operation":{"sync":{"prune":true}}}' 2>/dev/null || true
kubectl patch application iam-stack -n argocd --type merge -p '{"operation":{"sync":{"prune":true}}}' 2>/dev/null || true
echo -e "${GREEN}✅ Sync triggered${NC}\n"

echo -e "${GREEN}✅ Bootstrap complete!${NC}\n"
echo "Monitor: kubectl get applications -n argocd"
echo "UI: kubectl port-forward svc/argocd-server -n argocd 8080:443"
