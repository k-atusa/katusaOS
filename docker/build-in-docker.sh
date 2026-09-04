#!/usr/bin/env bash
# katusaOS Docker Container Builder Runner
set -euo pipefail

ARCH="${1:-amd64}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
BUILDER_TAG="katusaos-builder:latest"

echo "[+] ========================================================"
echo "[+] Starting katusaOS Docker Build for: ${ARCH}"
echo "[+] Repository: ${REPO_ROOT}"
echo "[+] ========================================================"

# Verify Docker availability
if ! command -v docker &> /dev/null; then
    echo "[-] Error: docker is not installed or not in PATH."
    exit 1
fi

# Build builder image
echo "[+] Building builder container image..."
docker build -t "${BUILDER_TAG}" -f "${SCRIPT_DIR}/Dockerfile.builder" "${SCRIPT_DIR}"

# Run build inside privileged container
echo "[+] Running build-image.sh inside container..."
docker run --rm --privileged \
    -v "${REPO_ROOT}:/workspace" \
    -e DEBIAN_FRONTEND=noninteractive \
    "${BUILDER_TAG}" \
    /workspace/scripts/build-image.sh "${ARCH}"

echo "[+] Docker build completed successfully!"
