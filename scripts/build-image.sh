#!/usr/bin/env bash
# katusaOS Disk Image & Kernel Artifacts Builder
# Builds bootable disk image and extracts vmlinuz/initrd for QEMU
set -euo pipefail

ARCH="${1:-amd64}"
IMAGE_SIZE_MB="${IMAGE_SIZE_MB:-4096}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
OUTPUT_DIR="${OUTPUT_DIR:-${REPO_ROOT}/output}"

# Use local container/system /tmp directory for building to avoid Docker virtiofs/9p nodev issues
BUILD_DIR="${BUILD_DIR:-/tmp/katusa-build-${ARCH}}"
ROOTFS_DIR="${BUILD_DIR}/rootfs"
IMAGE_PATH="${OUTPUT_DIR}/katusaOS-${ARCH}.img"

echo "[+] ========================================================"
echo "[+] katusaOS Image & Kernel Packaging"
echo "[+] Architecture: ${ARCH}"
echo "[+] Image Size:   ${IMAGE_SIZE_MB}MB"
echo "[+] Build Dir:    ${BUILD_DIR}"
echo "[+] Output Image: ${IMAGE_PATH}"
echo "[+] ========================================================"

# Ensure root
if [ "$(id -u)" -ne 0 ]; then
    echo "[-] Error: This script must be run as root (or inside Docker)."
    exit 1
fi

mkdir -p "${OUTPUT_DIR}"
chmod 777 "${OUTPUT_DIR}" 2>/dev/null || true
mkdir -p "${BUILD_DIR}"

# Step 1: Build rootfs if not already present
if [ ! -d "${ROOTFS_DIR}/bin" ]; then
    echo "[+] Building rootfs in local native filesystem..."
    "${SCRIPT_DIR}/build-rootfs.sh" "${ARCH}" "${ROOTFS_DIR}"
else
    echo "[+] Using existing rootfs at ${ROOTFS_DIR}..."
fi

# Step 2: Extract Kernel and Initrd for direct QEMU boot
echo "[+] Extracting kernel and initramfs for QEMU direct boot..."
VMLINUZ_FILE=$(find "${ROOTFS_DIR}/boot" -maxdepth 1 -name "vmlinuz*" | sort -V | tail -n 1)
INITRD_FILE=$(find "${ROOTFS_DIR}/boot" -maxdepth 1 \( -name "initramfs*" -o -name "initrd*" \) | sort -V | tail -n 1)

if [ -z "${VMLINUZ_FILE}" ] || [ -z "${INITRD_FILE}" ]; then
    echo "[-] Error: Could not find kernel or initrd in ${ROOTFS_DIR}/boot!"
    exit 1
fi

echo "[+] Found Kernel: ${VMLINUZ_FILE}"
echo "[+] Found Initrd: ${INITRD_FILE}"

cp -f "${VMLINUZ_FILE}" "${OUTPUT_DIR}/vmlinuz-${ARCH}"
cp -f "${INITRD_FILE}" "${OUTPUT_DIR}/initrd-${ARCH}.img"
chmod 666 "${OUTPUT_DIR}/vmlinuz-${ARCH}" "${OUTPUT_DIR}/initrd-${ARCH}.img" 2>/dev/null || true

# Step 3: Create raw ext4 disk image using mke2fs -d (no loop mount required)
echo "[+] Generating ${IMAGE_SIZE_MB}MB ext4 disk image directly from rootfs..."
rm -f "${IMAGE_PATH}"

# Create raw ext4 image populated with rootfs directory contents
mke2fs -t ext4 -d "${ROOTFS_DIR}" -F -L "katusa-root" "${IMAGE_PATH}" "${IMAGE_SIZE_MB}M"
chmod 666 "${IMAGE_PATH}" 2>/dev/null || true

echo "[+] ========================================================"
echo "[+] katusaOS Build Complete!"
echo "[+] Artifacts in ${OUTPUT_DIR}:"
echo "  - Disk Image: ${IMAGE_PATH} ($(du -h "${IMAGE_PATH}" | cut -f1))"
echo "  - Kernel:     ${OUTPUT_DIR}/vmlinuz-${ARCH}"
echo "  - Initramfs:  ${OUTPUT_DIR}/initrd-${ARCH}.img"
echo "[+] ========================================================"
