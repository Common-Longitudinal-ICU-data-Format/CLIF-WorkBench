#!/usr/bin/env bash
# =============================================================================
# Publish clif-workbench Docker images to Docker Hub
#
# Prerequisites:
#   docker login   (run once to authenticate with Docker Hub)
#
# Usage:
#   ./scripts/publish.sh ml              # Push ML image
#   ./scripts/publish.sh ai              # Push AI image
#   ./scripts/publish.sh all             # Push both
#   ./scripts/publish.sh ml  0.1.0       # Push ML image with version tag
#   ./scripts/publish.sh all 0.1.0       # Push both with version tags
#
# Environment:
#   DOCKERHUB_ORG  — Docker Hub org/user (default: clifconsortium)
# =============================================================================

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DOCKERHUB_ORG="${DOCKERHUB_ORG:-clifconsortium}"
IMAGE_NAME="clif-workbench"
REMOTE="${DOCKERHUB_ORG}/${IMAGE_NAME}"
TARGET="${1:-}"
VERSION="${2:-}"

# --- Verify docker login ---
check_login() {
    if ! docker info 2>/dev/null | grep -q "Username"; then
        echo "ERROR: Not logged in to Docker Hub."
        echo "Run:  docker login"
        exit 1
    fi
}

# --- Tag and push a single image ---
tag_and_push() {
    local tag="$1"

    echo "==> Tagging ${IMAGE_NAME}:${tag} -> ${REMOTE}:${tag}"
    docker tag "${IMAGE_NAME}:${tag}" "${REMOTE}:${tag}"
    docker push "${REMOTE}:${tag}"

    # Push versioned tag if version provided
    if [[ -n "${VERSION}" ]]; then
        echo "==> Tagging ${IMAGE_NAME}:${tag} -> ${REMOTE}:${VERSION}-${tag}"
        docker tag "${IMAGE_NAME}:${tag}" "${REMOTE}:${VERSION}-${tag}"
        docker push "${REMOTE}:${VERSION}-${tag}"
    fi
}

publish_ml() {
    tag_and_push "ml"

    # ML is also 'latest'
    echo "==> Tagging ${IMAGE_NAME}:ml -> ${REMOTE}:latest"
    docker tag "${IMAGE_NAME}:ml" "${REMOTE}:latest"
    docker push "${REMOTE}:latest"
}

publish_ai() {
    tag_and_push "ai"
}

# --- Main ---
if [[ -z "${TARGET}" ]]; then
    echo "Usage: $0 {ml|ai|all} [version]"
    echo ""
    echo "Examples:"
    echo "  $0 ml              # Push ML image"
    echo "  $0 all 0.1.0       # Push both with version tags"
    echo ""
    echo "Set DOCKERHUB_ORG to override org (default: clifconsortium)"
    exit 1
fi

check_login

case "${TARGET}" in
    ml)
        publish_ml
        ;;
    ai)
        publish_ai
        ;;
    all)
        publish_ml
        publish_ai
        ;;
    *)
        echo "Usage: $0 {ml|ai|all} [version]"
        exit 1
        ;;
esac

echo ""
echo "==> Published to Docker Hub: ${REMOTE}"
echo "    Pull with: docker pull ${REMOTE}:ml"
