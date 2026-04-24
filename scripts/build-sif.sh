#!/usr/bin/env bash
# =============================================================================
# Convert a locally-built clif-workbench Docker image into a .sif file.
#
# Prerequisites:
#   - Docker image built locally (run ./scripts/build.sh <kind> first)
#   - Apptainer installed (apptainer --version)
#
# Usage:
#   ./scripts/build-sif.sh ml 0.1.0     # -> clif-ml-0.1.0.sif (+ .sha256)
#   ./scripts/build-sif.sh ai 0.1.0     # -> clif-ai-0.1.0.sif (+ .sha256)
# =============================================================================

set -euo pipefail

IMAGE_NAME="clif-workbench"
KIND="${1:-}"
VERSION="${2:-}"

if [[ -z "${KIND}" || -z "${VERSION}" ]]; then
    echo "Usage: $0 {ml|ai} <version>"
    echo "Example: $0 ml 0.1.0"
    exit 1
fi

case "${KIND}" in
    ml|ai) ;;
    *)
        echo "ERROR: kind must be 'ml' or 'ai' (got: ${KIND})"
        exit 1
        ;;
esac

DOCKER_TAG="${IMAGE_NAME}:${KIND}"
SIF_FILE="clif-${KIND}-${VERSION}.sif"

if ! command -v apptainer > /dev/null 2>&1; then
    echo "ERROR: apptainer not found in PATH."
    exit 1
fi

if ! docker image inspect "${DOCKER_TAG}" > /dev/null 2>&1; then
    echo "ERROR: Docker image ${DOCKER_TAG} not found locally."
    echo "Build it first: ./scripts/build.sh ${KIND}"
    exit 1
fi

echo "==> Converting ${DOCKER_TAG} -> ${SIF_FILE}"
apptainer build --force "${SIF_FILE}" "docker-daemon://${DOCKER_TAG}"

echo "==> Computing SHA256"
sha256sum "${SIF_FILE}" > "${SIF_FILE}.sha256"

echo ""
echo "==> Done."
ls -lh "${SIF_FILE}" "${SIF_FILE}.sha256"
echo ""
echo "Next: ./scripts/publish-sif.sh ${KIND} ${VERSION}"
