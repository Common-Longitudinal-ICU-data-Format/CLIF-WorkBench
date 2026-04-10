#!/usr/bin/env bash
# =============================================================================
# Build clif-workbench Docker images
#
# Usage:
#   ./scripts/build.sh ml     # Build ML image
#   ./scripts/build.sh ai     # Build AI image
#   ./scripts/build.sh all    # Build both
# =============================================================================

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
IMAGE_NAME="clif-workbench"

build_ml() {
    echo "==> Building ${IMAGE_NAME}:ml ..."
    docker build \
        -t "${IMAGE_NAME}:ml" \
        -t "${IMAGE_NAME}:latest" \
        -f "${REPO_ROOT}/images/ml/Dockerfile" \
        "${REPO_ROOT}/images/ml/"
    echo "==> Done: ${IMAGE_NAME}:ml"
}

build_ai() {
    echo "==> Building ${IMAGE_NAME}:ai ..."
    docker build \
        -t "${IMAGE_NAME}:ai" \
        -f "${REPO_ROOT}/images/ai/Dockerfile" \
        "${REPO_ROOT}/images/ai/"
    echo "==> Done: ${IMAGE_NAME}:ai"
}

case "${1:-}" in
    ml)
        build_ml
        ;;
    ai)
        build_ai
        ;;
    all)
        build_ml
        build_ai
        ;;
    *)
        echo "Usage: $0 {ml|ai|all}"
        exit 1
        ;;
esac
