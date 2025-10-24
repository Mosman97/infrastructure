#!/bin/zsh

# Infrastructure Repository Restructuring Script
# Creates a clean, consistent folder structure

set -e  # Exit on error

echo "🚀 Starting infrastructure restructuring..."

# Create new directory structure
echo "📁 Creating new directories..."
mkdir -p certificates
mkdir -p argocd/projects
mkdir -p argocd/applications
mkdir -p deployments/iam
mkdir -p operator

# Move certificates
echo "🔒 Moving certificates..."
mv tls.crt certificates/keycloak.local.crt
mv tls.key certificates/keycloak.local.key

# Move ArgoCD definitions
echo "⚙️  Moving ArgoCD configurations..."
mv projects/project-iam.yaml argocd/projects/iam-project.yaml
mv apps-argo/iam-stack.yaml argocd/applications/iam-application.yaml

# Move and rename IAM deployment files
echo "📦 Moving IAM deployments..."
mv apps/iam/kustomization.yaml deployments/iam/kustomization.yaml
mv apps/iam/postgres.yaml deployments/iam/database-postgres.yaml
mv apps/iam/keycloak.yaml deployments/iam/keycloak-instance.yaml
mv apps/iam/secrets.yaml deployments/iam/secrets-credentials.yaml
mv apps/iam/ingress.yaml deployments/iam/ingress-keycloak.yaml

# Move operator files
echo "🔧 Moving operator configuration..."
mv apps/keycloak-operator/kustomization.yaml operator/helm-kustomization.yaml
mv apps/keycloak-operator/secrets.yaml operator/secrets-template.yaml
mv apps/keycloak-operator/values.yaml operator/values.yaml

# Clean up old directories
echo "🧹 Cleaning up old directories..."
rmdir apps/iam
rmdir apps/keycloak-operator
rmdir apps-argo
rmdir projects

# Remove example files (not needed)
echo "🗑️  Removing example files..."
rm -rf apps/keycloak
rm -rf apps/postgres
rmdir apps 2>/dev/null || true

echo "✅ Restructuring complete!"
echo ""
echo "📋 New structure:"
echo "  certificates/          - TLS certificates"
echo "  argocd/               - ArgoCD projects & applications"
echo "  deployments/iam/      - IAM stack deployment files"
echo "  operator/             - Keycloak operator configuration"
echo ""
echo "⚠️  Next steps:"
echo "  1. Review the changes: git status"
echo "  2. Update any hardcoded paths in your files"
echo "  3. Commit: git add -A && git commit -m 'refactor: restructure repository'"
