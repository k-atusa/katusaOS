#!/usr/bin/env bash
# katusaOS Disk Image, UEFI ISO & Kernel Artifacts Builder
# Builds UEFI-bootable GPT disk image, bootable installer ISO, and extracts vmlinuz/initrd
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
ISO_PATH="${OUTPUT_DIR}/katusaOS-${ARCH}-installer.iso"

echo "[+] ========================================================"
echo "[+] katusaOS Image, ISO & Kernel Packaging"
echo "[+] Architecture: ${ARCH}"
echo "[+] Image Size:   ${IMAGE_SIZE_MB}MB"
echo "[+] Build Dir:    ${BUILD_DIR}"
echo "[+] Output Disk:  ${IMAGE_PATH}"
echo "[+] Output ISO:   ${ISO_PATH}"
echo "[+] ========================================================"

# Ensure root
if [ "$(id -u)" -ne 0 ]; then
    echo "[-] Error: This script must be run as root (or inside Docker)."
    exit 1
fi

mkdir -p "${OUTPUT_DIR}"
chmod 777 "${OUTPUT_DIR}" 2>/dev/null || true
mkdir -p "${BUILD_DIR}"

# Determine EFI target names based on architecture
case "${ARCH}" in
    arm64|aarch64)
        GRUB_TARGET="arm64-efi"
        EFI_BINARY="BOOTAA64.EFI"
        CONSOLE="ttyAMA0"
        ;;
    amd64|x86_64)
        GRUB_TARGET="x86_64-efi"
        EFI_BINARY="BOOTX64.EFI"
        CONSOLE="ttyS0"
        ;;
    *)
        echo "[-] Error: Unsupported architecture: ${ARCH}"
        exit 1
        ;;
esac

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

# Step 3: Configure GRUB on rootfs
echo "[+] Configuring GRUB bootloader on rootfs..."
mkdir -p "${ROOTFS_DIR}/boot/grub"
cat << 'EOF' > "${ROOTFS_DIR}/boot/grub/grub.cfg"
set default=0
set timeout=3

insmod part_gpt
insmod ext2
insmod fat
insmod iso9660
insmod all_video

menuentry 'katusaOS' {
    search --no-floppy --set=root --label katusa-root
    linux /boot/vmlinuz-virt root=LABEL=katusa-root rw modules=ext4,virtio_pci,virtio_blk,virtio_gpu console=tty0 console=${CONSOLE} quiet
    initrd /boot/initramfs-virt
}

menuentry 'katusaOS (Fallback Recovery)' {
    search --no-floppy --set=root --label katusa-root
    linux /boot/vmlinuz-virt root=LABEL=katusa-root rw modules=ext4,virtio_pci,virtio_blk,virtio_gpu console=tty0 console=${CONSOLE} single
    initrd /boot/initramfs-virt
}
EOF

# Step 4: Build standalone EFI bootloader binary with embedded early search config
echo "[+] Generating early GRUB bootstrap config..."
cat << 'EOF' > "${BUILD_DIR}/early-grub.cfg"
search --no-floppy --set=root --label katusa-root
set prefix=($root)/boot/grub
configfile ($root)/boot/grub/grub.cfg
EOF

echo "[+] Generating GRUB EFI executable (${EFI_BINARY})..."
grub-mkimage -O "${GRUB_TARGET}" \
    -c "${BUILD_DIR}/early-grub.cfg" \
    -o "${BUILD_DIR}/${EFI_BINARY}" \
    -p "/boot/grub" \
    fat ext2 iso9660 part_gpt part_msdos search search_fs_uuid search_label normal configfile linux test echo all_video efi_gop efitextmode loadenv reboot

# Step 5: Build EFI System Partition (ESP) image
ESP_SIZE_MB=64
echo "[+] Creating ${ESP_SIZE_MB}MB FAT32 EFI System Partition (ESP)..."
rm -f "${BUILD_DIR}/esp.img"
dd if=/dev/zero of="${BUILD_DIR}/esp.img" bs=1M count="${ESP_SIZE_MB}" status=none
mkfs.vfat -F32 -n "KATUSA-ESP" "${BUILD_DIR}/esp.img" > /dev/null

mmd -i "${BUILD_DIR}/esp.img" ::EFI
mmd -i "${BUILD_DIR}/esp.img" ::EFI/BOOT
mmd -i "${BUILD_DIR}/esp.img" ::boot
mmd -i "${BUILD_DIR}/esp.img" ::boot/grub
mcopy -i "${BUILD_DIR}/esp.img" "${BUILD_DIR}/${EFI_BINARY}" "::EFI/BOOT/${EFI_BINARY}"
mcopy -i "${BUILD_DIR}/esp.img" "${BUILD_DIR}/early-grub.cfg" "::EFI/BOOT/grub.cfg"
mcopy -i "${BUILD_DIR}/esp.img" "${BUILD_DIR}/early-grub.cfg" "::boot/grub/grub.cfg"

# Step 6: Prepare ISO rootfs copy first (preserves live installer prompts & login credentials for Live ISO)
ISO_ROOT="${BUILD_DIR}/iso_root"
rm -rf "${ISO_ROOT}"
mkdir -p "${ISO_ROOT}"
echo "[+] Copying complete rootfs into ISO root..."
rsync -aHAX --exclude=/proc/* --exclude=/sys/* --exclude=/dev/* --exclude=/run/* --exclude=/tmp/* "${ROOTFS_DIR}/" "${ISO_ROOT}/"
mkdir -p "${ISO_ROOT}/proc" "${ISO_ROOT}/sys" "${ISO_ROOT}/dev" "${ISO_ROOT}/run" "${ISO_ROOT}/tmp"
chmod 1777 "${ISO_ROOT}/tmp"

# Configure ROOTFS_DIR for pre-installed disk image (remove installer prompts and default user/pw banner)
touch "${ROOTFS_DIR}/etc/katusa-installed"
if [ -f "${ROOTFS_DIR}/etc/issue" ]; then
    sed -i '/katusa-install/d; /Default User/d; /Password/d' "${ROOTFS_DIR}/etc/issue"
fi
if [ -f "${ROOTFS_DIR}/etc/issue.net" ]; then
    sed -i '/katusa-install/d; /Default User/d; /Password/d' "${ROOTFS_DIR}/etc/issue.net"
fi
if [ -f "${ROOTFS_DIR}/etc/motd" ]; then
    sed -i '/katusa-install/d; /install katusaOS permanently/d; /Default User/d; /Password/d' "${ROOTFS_DIR}/etc/motd"
fi

# Step 7: Build ext4 Root Filesystem partition image
ROOT_SIZE_MB=$((IMAGE_SIZE_MB - ESP_SIZE_MB - 2))
echo "[+] Creating ${ROOT_SIZE_MB}MB ext4 rootfs partition image..."
rm -f "${BUILD_DIR}/root.img"
mke2fs -t ext4 -d "${ROOTFS_DIR}" -F -L "katusa-root" "${BUILD_DIR}/root.img" "${ROOT_SIZE_MB}M" > /dev/null

# Step 8: Assemble GPT UEFI Disk Image
echo "[+] Assembling GPT partitioned disk image (${IMAGE_PATH})..."
rm -f "${IMAGE_PATH}"
# Create sparse disk image
dd if=/dev/zero of="${IMAGE_PATH}" bs=1M count=1 seek=$((IMAGE_SIZE_MB - 1)) status=none

parted -s "${IMAGE_PATH}" mklabel gpt
parted -s "${IMAGE_PATH}" mkpart ESP fat32 1MiB $((ESP_SIZE_MB + 1))MiB
parted -s "${IMAGE_PATH}" set 1 esp on
parted -s "${IMAGE_PATH}" mkpart root ext4 $((ESP_SIZE_MB + 1))MiB 100%

# Write ESP partition at 1MiB offset
dd if="${BUILD_DIR}/esp.img" of="${IMAGE_PATH}" bs=1M seek=1 conv=notrunc status=none

# Write Root partition at (ESP_SIZE_MB + 1) offset
dd if="${BUILD_DIR}/root.img" of="${IMAGE_PATH}" bs=1M seek=$((ESP_SIZE_MB + 1)) conv=notrunc status=none
chmod 666 "${IMAGE_PATH}" 2>/dev/null || true

# Step 9: Build Bootable UEFI Live & Installer ISO for UTM
echo "[+] Generating bootable UEFI installer ISO (${ISO_PATH})..."

# Configure GRUB for ISO
mkdir -p "${ISO_ROOT}/boot/grub" "${ISO_ROOT}/EFI/BOOT"
cat << EOF > "${ISO_ROOT}/boot/grub/grub.cfg"
set default=0
set timeout=3

insmod part_gpt
insmod fat
insmod iso9660
insmod all_video

menuentry 'Install katusaOS (Live Installer)' {
    linux /boot/vmlinuz-virt root=LABEL=KATUSA_ISO overlaytmpfs=yes modules=ext4,isofs,virtio_pci,virtio_blk,virtio_gpu,overlay console=tty0 console=${CONSOLE} quiet
    initrd /boot/initramfs-virt
}

menuentry 'katusaOS (Live Mode)' {
    linux /boot/vmlinuz-virt root=LABEL=KATUSA_ISO overlaytmpfs=yes modules=ext4,isofs,virtio_pci,virtio_blk,virtio_gpu,overlay console=tty0 console=${CONSOLE} quiet
    initrd /boot/initramfs-virt
}

menuentry 'katusaOS (Debug Verbose Boot)' {
    linux /boot/vmlinuz-virt root=LABEL=KATUSA_ISO overlaytmpfs=yes modules=ext4,isofs,virtio_pci,virtio_blk,virtio_gpu,overlay console=tty0 console=${CONSOLE}
    initrd /boot/initramfs-virt
}
EOF
cp -f "${ISO_ROOT}/boot/grub/grub.cfg" "${ISO_ROOT}/EFI/BOOT/grub.cfg"

# Build dedicated EFI bootloader for ISO
cat << 'EOF' > "${BUILD_DIR}/early-iso.cfg"
search --no-floppy --set=root --label KATUSA_ISO
set prefix=($root)/boot/grub
configfile ($root)/boot/grub/grub.cfg
EOF

grub-mkimage -O "${GRUB_TARGET}" \
    -c "${BUILD_DIR}/early-iso.cfg" \
    -o "${BUILD_DIR}/iso-${EFI_BINARY}" \
    -p "/boot/grub" \
    fat ext2 iso9660 part_gpt part_msdos search search_fs_uuid search_label normal configfile linux test echo all_video efi_gop efitextmode loadenv reboot

# Create efi.img for ISO
rm -f "${ISO_ROOT}/efi.img"
dd if=/dev/zero of="${ISO_ROOT}/efi.img" bs=1M count=16 status=none
mkfs.vfat "${ISO_ROOT}/efi.img" > /dev/null
mmd -i "${ISO_ROOT}/efi.img" ::EFI
mmd -i "${ISO_ROOT}/efi.img" ::EFI/BOOT
mcopy -i "${ISO_ROOT}/efi.img" "${BUILD_DIR}/iso-${EFI_BINARY}" "::EFI/BOOT/${EFI_BINARY}"
mcopy -i "${ISO_ROOT}/efi.img" "${BUILD_DIR}/early-iso.cfg" "::EFI/BOOT/grub.cfg"

echo "[+] Mastering ISO with xorriso..."
xorriso -as mkisofs \
    -R \
    -V "KATUSA_ISO" \
    -e efi.img \
    -no-emul-boot \
    -isohybrid-gpt-basdat \
    -o "${ISO_PATH}" \
    "${ISO_ROOT}" > /dev/null 2>&1 || true

if [ -f "${ISO_PATH}" ]; then
    chmod 666 "${ISO_PATH}" 2>/dev/null || true
fi

# Cleanup build temp images to free disk space
rm -f "${BUILD_DIR}/esp.img" "${BUILD_DIR}/root.img" "${BUILD_DIR}/early-iso.cfg" "${BUILD_DIR}/iso-${EFI_BINARY}"
rm -rf "${ISO_ROOT}"

echo "[+] ========================================================"
echo "[+] katusaOS Build Complete!"
echo "[+] Artifacts in ${OUTPUT_DIR}:"
echo "  - UEFI GPT Disk Image: ${IMAGE_PATH} ($(du -h "${IMAGE_PATH}" | cut -f1))"
if [ -f "${ISO_PATH}" ]; then
    echo "  - UEFI Installer ISO:  ${ISO_PATH} ($(du -h "${ISO_PATH}" | cut -f1))"
fi
echo "  - Kernel:              ${OUTPUT_DIR}/vmlinuz-${ARCH}"
echo "  - Initramfs:           ${OUTPUT_DIR}/initrd-${ARCH}.img"
echo "[+] ========================================================"
