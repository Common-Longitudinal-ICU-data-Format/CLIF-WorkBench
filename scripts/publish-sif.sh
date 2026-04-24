#!/usr/bin/env bash
# =============================================================================
# Upload a clif-workbench .sif (+ .sha256) to the matching GitHub Release.
#
# Prerequisites:
#   - .sif built locally (run ./scripts/build-sif.sh <kind> <version> first)
#   - GitHub Release vX.Y.Z already exists (gh release create vX.Y.Z ...)
#   - gh CLI authenticated (gh auth status)
#
# Usage:
#   ./scripts/publish-sif.sh ml 0.1.0
#   ./scripts/publish-sif.sh ai 0.1.0    # refuses — AI exceeds GH 2 GB cap
# =============================================================================

set -euo pipefail

KIND="${1:-}"
VERSION="${2:-}"

if [[ -z "${KIND}" || -z "${VERSION}" ]]; then
    echo "Usage: $0 {ml|ai} <version>"
    exit 1
fi

SIF_FILE="clif-${KIND}-${VERSION}.sif"
SHA_FILE="${SIF_FILE}.sha256"
RELEASE_TAG="v${VERSION}"

if [[ "${KIND}" == "ai" ]]; then
    echo "ERROR: the AI image (~10 GB) exceeds GitHub's 2 GB per-file cap."
    echo "GitHub Releases will refuse the upload."
    echo ""
    echo "Offline paths for the AI image:"
    echo "  1. Users copy the .sif from a colleague (scp/USB — documented in README)."
    echo "  2. If needed, upload to Zenodo manually (https://zenodo.org) for a DOI-backed download URL."
    exit 1
fi

if [[ ! -f "${SIF_FILE}" || ! -f "${SHA_FILE}" ]]; then
    echo "ERROR: ${SIF_FILE} or ${SHA_FILE} not found in the current directory."
    echo "Build it first: ./scripts/build-sif.sh ${KIND} ${VERSION}"
    exit 1
fi

if ! command -v gh > /dev/null 2>&1; then
    echo "ERROR: gh CLI not found. Install from https://cli.github.com/"
    exit 1
fi

if ! gh auth status > /dev/null 2>&1; then
    echo "ERROR: gh CLI not authenticated. Run: gh auth login"
    exit 1
fi

if ! gh release view "${RELEASE_TAG}" > /dev/null 2>&1; then
    echo "ERROR: GitHub Release ${RELEASE_TAG} does not exist."
    echo "Create it first:"
    echo "  git tag ${RELEASE_TAG} && git push --tags"
    echo "  gh release create ${RELEASE_TAG} --generate-notes"
    exit 1
fi

echo "==> Uploading ${SIF_FILE} + ${SHA_FILE} to release ${RELEASE_TAG}"
gh release upload "${RELEASE_TAG}" "${SIF_FILE}" "${SHA_FILE}" --clobber

echo ""
echo "==> Done."
echo "Users can now install with:"
echo "  wget https://github.com/Common-Longitudinal-ICU-data-Format/CLIF-WorkBench/releases/download/${RELEASE_TAG}/${SIF_FILE}"
echo "  wget https://github.com/Common-Longitudinal-ICU-data-Format/CLIF-WorkBench/releases/download/${RELEASE_TAG}/${SHA_FILE}"
echo "  sha256sum -c ${SHA_FILE}"
