#!/bin/bash
set -e

REGISTRY="registry.pharah.ca"
NAMESPACE="web"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

deploy() {
  local name=$1
  local dir=$2
  local deployment=$3

  echo "Building $name..."
  docker build -t "$REGISTRY/$name:latest" "$dir"

  echo "Pushing to $REGISTRY..."
  docker push "$REGISTRY/$name:latest"

  echo "Restarting deployment..."
  kubectl rollout restart deployment/$deployment -n $NAMESPACE
  kubectl rollout status deployment/$deployment -n $NAMESPACE --timeout=60s

  echo "$name deployed successfully"
}

TARGET=${1:-all}

case $TARGET in
  client)
    deploy "shychedelic" "$SCRIPT_DIR/client" "shychedelic"
    ;;
  server)
    deploy "shychedelic-api" "$SCRIPT_DIR/server" "shychedelic-api"
    ;;
  all)
    deploy "shychedelic" "$SCRIPT_DIR/client" "shychedelic"
    deploy "shychedelic-api" "$SCRIPT_DIR/server" "shychedelic-api"
    ;;
  *)
    echo "Usage: $0 [client|server|all]"
    exit 1
    ;;
esac
