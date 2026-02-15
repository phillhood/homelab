#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

ARGO_CHART=argo-cd
ARGO_REPO=https://argoproj.github.io/argo-helm
ARGO_VERSION=7.9.1

log() { echo -e "${GREEN}[INFO]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

wait_for_deployment() {
    local namespace=$1
    local deployment=$2
    local timeout=${3:-120}

    log "Waiting for $deployment in $namespace..."
    kubectl rollout status deployment/$deployment -n $namespace --timeout=${timeout}s
}

case "${1:-deploy}" in
    deploy)
        log "Bootstrapping ArgoCD..."

        helm repo add argo https://argoproj.github.io/argo-helm --force-update
        helm upgrade --install argocd $ARGO_CHART \
            --repo $ARGO_REPO \
            --version $ARGO_VERSION \
            -n argocd --create-namespace \
            -f argocd/helm-values.yaml
        wait_for_deployment argocd argocd-server

        log "Applying manifests..."
        kubectl apply -f argocd/ingress.yaml
        kubectl apply -f argocd/project.yaml
        kubectl apply -f argocd/appset.yaml

        log "ArgoCD deployed. Access UI at https://argocd.pharah.ca"
        log "Get admin password: $0 password"
        ;;

    password)
        kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d
        echo
        ;;

    *)
        echo "Usage: $0 {deploy|password}"
        echo "  deploy   - Bootstrap ArgoCD"
        echo "  password - Get ArgoCD admin password"
        exit 1
        ;;
esac
