#!/bin/bash
set -e

RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
NC='\033[0m'

echo -e "${RED}🧹 Cleaning up Kubernetes Infrastructure${NC}"
echo ""

echo -e "${YELLOW}Step 1/4: Deleting ArgoCD Applications...${NC}"
kubectl delete applications -n argocd --all --ignore-not-found=true 2>/dev/null || true
sleep 5
echo -e "${GREEN}✅ Applications deleted${NC}"
echo ""

echo -e "${YELLOW}Step 2/4: Deleting namespaces...${NC}"
kubectl delete namespace argocd istio-system observability iam-system --force --grace-period=0 2>/dev/null || true
sleep 10
echo -e "${GREEN}✅ Namespaces deletion initiated${NC}"
echo ""

echo -e "${YELLOW}Step 3/4: Force finalizing stuck namespaces...${NC}"
for ns in argocd istio-system observability iam-system; do
  if kubectl get namespace $ns 2>/dev/null | grep -q Terminating; then
    echo "Finalizing $ns..."
    kubectl get namespace $ns -o json 2>/dev/null | jq '.spec.finalizers = []' | kubectl replace --raw /api/v1/namespaces/$ns/finalize -f - >/dev/null 2>&1 || true
  fi
done
sleep 5
echo -e "${GREEN}✅ Namespaces finalized${NC}"
echo ""

echo -e "${YELLOW}Step 4/4: Cleaning up PVCs and PVs...${NC}"
# Delete all PVCs that might be stuck
kubectl get pvc --all-namespaces -o json | jq -r '.items[] | select(.metadata.namespace | test("argocd|istio-system|observability|iam-system")) | "\(.metadata.namespace) \(.metadata.name)"' | while read ns name; do
  echo "Deleting PVC $name in namespace $ns"
  kubectl delete pvc $name -n $ns --force --grace-period=0 2>/dev/null || true
done

# Delete orphaned PVs
kubectl get pv -o json | jq -r '.items[] | select(.spec.claimRef.namespace | test("argocd|istio-system|observability|iam-system")) | .metadata.name' | while read pv; do
  echo "Deleting PV $pv"
  kubectl delete pv $pv --force --grace-period=0 2>/dev/null || true
done

sleep 5
echo -e "${GREEN}✅ PVCs and PVs cleaned${NC}"
echo ""

echo -e "${YELLOW}Waiting for cleanup to complete...${NC}"
timeout=60
elapsed=0
while [ $elapsed -lt $timeout ]; do
  remaining=$(kubectl get namespaces | grep -E 'argocd|istio-system|observability|iam-system' | wc -l || echo 0)
  if [ "$remaining" -eq 0 ]; then
    echo -e "${GREEN}✅ Cleanup complete!${NC}"
    echo ""
    echo "🚀 Ready for fresh bootstrap:"
    echo "   ./bootstrap/install-argocd.sh"
    echo ""
    exit 0
  fi
  sleep 5
  elapsed=$((elapsed + 5))
  if [ $((elapsed % 15)) -eq 0 ]; then
    echo "Still cleaning... ($elapsed/$timeout seconds, $remaining namespaces remaining)"
  fi
done

echo -e "${YELLOW}⚠️  Cleanup taking longer than expected${NC}"
echo "Remaining namespaces:"
kubectl get namespaces | grep -E 'argocd|istio-system|observability|iam-system' || echo "None"
echo ""
echo "You can proceed with bootstrap, or wait longer for cleanup to complete."
echo ""
