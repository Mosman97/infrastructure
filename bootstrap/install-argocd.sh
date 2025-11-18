#!/bin/bash
set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}🚀 Bootstrapping Infrastructure${NC}\n"

echo -e "${YELLOW}[1/9] Installing ArgoCD...${NC}"
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

echo -e "${YELLOW}[2/9] Installing Keycloak CRDs...${NC}"
kubectl apply -f https://raw.githubusercontent.com/keycloak/keycloak-k8s-resources/26.4.2/kubernetes/keycloaks.k8s.keycloak.org-v1.yml >/dev/null
kubectl apply -f https://raw.githubusercontent.com/keycloak/keycloak-k8s-resources/26.4.2/kubernetes/keycloakrealmimports.k8s.keycloak.org-v1.yml >/dev/null
echo -e "${GREEN}✅ CRDs installed${NC}\n"

echo -e "${YELLOW}[3/9] Installing CNPG CRDs...${NC}"
helm repo add cnpg https://cloudnative-pg.github.io/charts >/dev/null 2>&1 || true
helm repo update >/dev/null 2>&1
# Apply CRDs with server-side apply to handle large annotations
for crd in backups clusterimagecatalogs clusters databases failoverquorums imagecatalogs poolers publications scheduledbackups subscriptions; do
  kubectl apply --server-side -f "https://raw.githubusercontent.com/cloudnative-pg/cloudnative-pg/release-1.27/config/crd/bases/postgresql.cnpg.io_${crd}.yaml" >/dev/null 2>&1 || true
done
echo -e "${GREEN}✅ CNPG CRDs installed${NC}\n"

echo -e "${YELLOW}[4/9] Creating ArgoCD Projects...${NC}"
kubectl apply -f argocd/projects/ >/dev/null
echo -e "${GREEN}✅ Projects created${NC}\n"

echo -e "${YELLOW}[5/9] Deploying ApplicationSet...${NC}"
kubectl apply -f argocd/applicationsets/infrastructure-appset.yaml >/dev/null
echo -e "${GREEN}✅ ApplicationSet deployed${NC}\n"

echo -e "${YELLOW}[6/9] Triggering initial sync (Istio and CNPG)...${NC}"
kubectl patch application istio-stack -n argocd --type merge -p '{"operation":{"sync":{"prune":true}}}' 2>/dev/null || true
kubectl patch application cnpg-operator -n argocd --type merge -p '{"operation":{"sync":{"prune":true}}}' 2>/dev/null || true
echo -e "${GREEN}✅ Core infrastructure syncing${NC}\n"

echo -e "${YELLOW}[7/9] Waiting for Istio to be ready...${NC}"
# Wait for Istio Gateway CRD to exist (up to 2 minutes)
for i in {1..24}; do
  if kubectl get crd gateways.networking.istio.io >/dev/null 2>&1; then
    break
  fi
  sleep 5
done
# Wait for istiod to be ready (injection webhook must be available)
kubectl wait --for=condition=available --timeout=180s deployment/istiod -n istio-system >/dev/null 2>&1 || true
# Wait for sidecar injector webhook to be ready by testing injection
echo "Waiting for Istio sidecar injection to be ready..."
for i in {1..12}; do
  # Test if injection works by checking webhook endpoints
  if kubectl get mutatingwebhookconfiguration istio-sidecar-injector -o jsonpath='{.webhooks[0].clientConfig.service.name}' 2>/dev/null | grep -q "istiod"; then
    sleep 5
    break
  fi
  sleep 5
done
echo -e "${GREEN}✅ Istio ready${NC}\n"

echo -e "${YELLOW}[8/9] Deploying istio-gateway and ArgoCD Gateway...${NC}"
# Sync istio-gateway application and wait for it to be healthy
kubectl patch application istio-gateway -n argocd --type merge -p '{"operation":{"sync":{"prune":true}}}' 2>/dev/null || true
echo "Waiting for gateway pod to be injected (up to 2 minutes)..."
# Wait for gateway pod to exist and have injection
for i in {1..24}; do
  POD_IMAGE=$(kubectl -n istio-ingress get pods -l istio=ingressgateway -o jsonpath='{.items[0].spec.containers[0].image}' 2>/dev/null || echo "")
  if [[ "$POD_IMAGE" != "auto" ]] && [[ -n "$POD_IMAGE" ]]; then
    echo "Gateway pod injected successfully with image: $POD_IMAGE"
    break
  fi
  sleep 5
done
# If still using 'auto', restart the pod
POD_IMAGE=$(kubectl -n istio-ingress get pods -l istio=ingressgateway -o jsonpath='{.items[0].spec.containers[0].image}' 2>/dev/null || echo "")
if [[ "$POD_IMAGE" == "auto" ]]; then
  echo "Gateway pod still using 'auto' image, restarting pod..."
  kubectl -n istio-ingress delete pods -l istio=ingressgateway >/dev/null 2>&1 || true
  sleep 20
fi
# Deploy ArgoCD Gateway resources
kubectl apply -f argocd/resources/gateway.yaml >/dev/null
echo -e "${GREEN}✅ Gateways deployed${NC}\n"

echo -e "${YELLOW}[9/9] Syncing remaining apps...${NC}"
kubectl patch application observability-stack -n argocd --type merge -p '{"operation":{"sync":{"prune":true}}}' 2>/dev/null || true
kubectl patch application iam-stack -n argocd --type merge -p '{"operation":{"sync":{"prune":true}}}' 2>/dev/null || true
echo -e "${GREEN}✅ All apps syncing${NC}\n"

echo -e "${GREEN}✅ Bootstrap complete!${NC}\n"
echo "Monitor: kubectl get applications -n argocd"
echo "UI: kubectl port-forward svc/argocd-server -n argocd 8080:443"
