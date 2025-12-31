#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

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

wait_for_crd() {
    local crd=$1
    local timeout=${2:-60}

    log "Waiting for CRD $crd..."
    for i in $(seq 1 $timeout); do
        if kubectl get crd $crd &>/dev/null; then
            return 0
        fi
        sleep 1
    done
    error "Timeout waiting for CRD $crd"
}

if [[ ! -f "values.yaml" ]]; then
    error "values.yaml not found. Copy values.yaml.example and configure it."
fi

case "${1:-deploy}" in
    deps|dependencies)
        log "Updating Helm dependencies..."
        helm dependency update .
        for chart in apps/core/*/Chart.yaml apps/*/*/Chart.yaml; do
            dir=$(dirname "$chart")
            if grep -q "dependencies:" "$chart"; then
                log "Updating dependencies for $dir"
                helm dependency update "$dir"
            fi
        done
        ;;

    deploy)
        log "Starting full cluster deployment..."

        log "=== Phase 1 ==="
        helm dependency update apps/core/sealed-secrets
        helm upgrade --install sealed-secrets apps/core/sealed-secrets \
            -n sealed-secrets --create-namespace \
            -f values.yaml
        wait_for_deployment sealed-secrets sealed-secrets

        log "=== Phase 2 ==="

        helm dependency update apps/core/metallb
        helm upgrade --install metallb apps/core/metallb \
            -n metallb-system --create-namespace \
            -f values.yaml
        wait_for_crd ipaddresspools.metallb.io
        wait_for_deployment metallb-system metallb-controller

        helm upgrade --install metallb-config apps/core/metallb-config \
            -n metallb-system \
            -f values.yaml

        helm dependency update apps/core/cert-manager
        helm upgrade --install cert-manager apps/core/cert-manager \
            -n cert-manager --create-namespace \
            -f values.yaml
        wait_for_crd certificates.cert-manager.io
        wait_for_deployment cert-manager cert-manager
        wait_for_deployment cert-manager cert-manager-webhook

        helm upgrade --install cert-manager-config apps/core/cert-manager-config \
            -n cert-manager \
            -f values.yaml

        log "=== Phase 3 ==="

        helm upgrade --install coredns apps/core/coredns \
            -n kube-system \
            -f values.yaml

        helm upgrade --install traefik-config apps/core/traefik \
            -n kube-system \
            -f values.yaml

        helm upgrade --install cloudflare-tunnel apps/core/cloudflare-tunnel \
            -n cloudflare-tunnel --create-namespace \
            -f values.yaml
            
        log "=== Phase 4 ==="

        helm dependency update apps/core/loki
        helm upgrade --install loki apps/core/loki \
            -n monitoring --create-namespace \
            -f values.yaml

        helm dependency update apps/core/prometheus
        helm upgrade --install prometheus apps/core/prometheus \
            -n monitoring \
            -f values.yaml

        helm dependency update apps/core/grafana
        helm upgrade --install grafana apps/core/grafana \
            -n monitoring \
            -f values.yaml

        helm dependency update apps/core/promtail
        helm upgrade --install promtail apps/core/promtail \
            -n monitoring \
            -f values.yaml

        log "=== Phase 5 ==="

        helm upgrade --install pihole apps/core/pihole \
            -n default \
            -f values.yaml

        helm upgrade --install registry apps/core/registry \
            -n registry --create-namespace \
            -f values.yaml

        helm upgrade --install comet apps/media/comet \
            -n media --create-namespace \
            -f values.yaml

        helm upgrade --install zilean apps/media/zilean \
            -n media \
            -f values.yaml

        helm upgrade --install prowlarr apps/media/prowlarr \
            -n media \
            -f values.yaml

        helm upgrade --install homepage apps/web/homepage \
            -n web --create-namespace \
            -f values.yaml

        helm upgrade --install landing apps/web/landing \
            -n web \
            -f values.yaml

        log "=== Deployment Complete ==="
        ;;

    *)
        echo "Usage: $0 {deploy|deps}"
        echo "  deploy - Full cluster deployment in ordered phases"
        echo "  deps   - Update all Helm dependencies"
        exit 1
        ;;
esac
