#!/usr/bin/env bash
# katusaOS Rootfs Build Script
# Supports: amd64, arm64
set -euo pipefail

ARCH="${1:-amd64}"
ROOTFS_DIR="${2:-/tmp/katusa-build-${ARCH}/rootfs}"
DEBIAN_RELEASE="${DEBIAN_RELEASE:-bookworm}"
DEBIAN_MIRROR="${DEBIAN_MIRROR:-http://deb.debian.org/debian}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Validate Architecture
if [ "${ARCH}" != "amd64" ] && [ "${ARCH}" != "arm64" ]; then
    echo "[-] Error: Unsupported architecture '${ARCH}'. Use 'amd64' or 'arm64'."
    exit 1
fi

echo "[+] ========================================================"
echo "[+] Building katusaOS RootFS"
echo "[+] Target Architecture: ${ARCH}"
echo "[+] Debian Release:      ${DEBIAN_RELEASE}"
echo "[+] RootFS Directory:    ${ROOTFS_DIR}"
echo "[+] ========================================================"

# Ensure root privileges
if [ "$(id -u)" -ne 0 ]; then
    echo "[-] Error: This script must be run as root (or inside Docker)."
    exit 1
fi

# Clean up existing rootfs dir
rm -rf "${ROOTFS_DIR}"
mkdir -p "${ROOTFS_DIR}"

# Step 1: Debootstrap
echo "[+] Step 1/6: Running debootstrap for ${ARCH}..."
COMMON_PKGS="systemd,systemd-sysv,udev,iproute2,net-tools,isc-dhcp-client,sudo,curl,wget,ca-certificates,locales,openssh-server,nano,vim,less,procps"

if [ "${ARCH}" = "amd64" ]; then
    KERNEL_PKG="linux-image-amd64"
else
    KERNEL_PKG="linux-image-arm64"
fi

debootstrap \
    --arch="${ARCH}" \
    --variant=minbase \
    --include="${COMMON_PKGS},${KERNEL_PKG}" \
    "${DEBIAN_RELEASE}" \
    "${ROOTFS_DIR}" \
    "${DEBIAN_MIRROR}"

echo "[+] Step 2/6: Copying katusaOS configurations and packages..."

# Inject custom OS identity
cp "${REPO_ROOT}/configs/os-release" "${ROOTFS_DIR}/etc/os-release"
cp "${REPO_ROOT}/configs/hostname" "${ROOTFS_DIR}/etc/hostname"
cp "${REPO_ROOT}/configs/issue" "${ROOTFS_DIR}/etc/issue"
cp "${REPO_ROOT}/configs/issue" "${ROOTFS_DIR}/etc/issue.net"

# Copy MOTD
mkdir -p "${ROOTFS_DIR}/etc/update-motd.d"
cp "${REPO_ROOT}/configs/motd/00-header" "${ROOTFS_DIR}/etc/update-motd.d/00-header"
chmod +x "${ROOTFS_DIR}/etc/update-motd.d/00-header"

# Copy Skeleton dotfiles
mkdir -p "${ROOTFS_DIR}/etc/skel"
cp "${REPO_ROOT}/configs/skel/.bashrc" "${ROOTFS_DIR}/etc/skel/.bashrc"
cp "${REPO_ROOT}/configs/skel/.zshrc" "${ROOTFS_DIR}/etc/skel/.zshrc"
cp "${REPO_ROOT}/configs/skel/.tmux.conf" "${ROOTFS_DIR}/etc/skel/.tmux.conf"
cp "${REPO_ROOT}/configs/skel/.vimrc" "${ROOTFS_DIR}/etc/skel/.vimrc"

# Install katusa CLI tool
mkdir -p "${ROOTFS_DIR}/usr/local/bin"
cp "${REPO_ROOT}/packages/katusa-cli/katusa" "${ROOTFS_DIR}/usr/local/bin/katusa"
chmod +x "${ROOTFS_DIR}/usr/local/bin/katusa"

# Club share directory
mkdir -p "${ROOTFS_DIR}/usr/share/katusa/examples"
cat << 'EOF' > "${ROOTFS_DIR}/usr/share/katusa/README.txt"
Welcome to katusaOS!
Katusa Programming Club Dedicated Operating System.

Check out 'katusa --help' for CLI utilities and starter templates.
EOF

echo "[+] Step 3/6: Configuring network and system mounts..."

# DNS Resolver
cat << 'EOF' > "${ROOTFS_DIR}/etc/resolv.conf"
nameserver 1.1.1.1
nameserver 8.8.8.8
EOF

# Network interfaces configuration
mkdir -p "${ROOTFS_DIR}/etc/network"
cat << 'EOF' > "${ROOTFS_DIR}/etc/network/interfaces"
auto lo
iface lo inet loopback

auto eth0
iface eth0 inet dhcp

allow-hotplug enp0s3
iface enp0s3 inet dhcp
EOF

# Modern systemd-networkd DHCP config for all wired interfaces
mkdir -p "${ROOTFS_DIR}/etc/systemd/network"
cat << 'EOF' > "${ROOTFS_DIR}/etc/systemd/network/20-wired.network"
[Match]
Name=en* eth*

[Network]
DHCP=yes
EOF

# Hosts file
cat << 'EOF' > "${ROOTFS_DIR}/etc/hosts"
127.0.0.1   localhost
127.0.1.1   katusaOS

# The following lines are desirable for IPv6 capable hosts
::1     localhost ip6-localhost ip6-loopback
ff02::1 ip6-allnodes
ff02::2 ip6-allrouters
EOF

# fstab
cat << 'EOF' > "${ROOTFS_DIR}/etc/fstab"
# /etc/fstab: static file system information.
/dev/root       /               ext4    errors=remount-ro 0       1
tmpfs           /tmp            tmpfs   defaults          0       0
EOF

# Apt Sources
cat << EOF > "${ROOTFS_DIR}/etc/apt/sources.list"
deb ${DEBIAN_MIRROR} ${DEBIAN_RELEASE} main contrib non-free non-free-firmware
deb ${DEBIAN_MIRROR} ${DEBIAN_RELEASE}-updates main contrib non-free non-free-firmware
deb http://security.debian.org/debian-security ${DEBIAN_RELEASE}-security main contrib non-free non-free-firmware
EOF

echo "[+] Step 4/6: Configuring users, packages and developer tools inside chroot..."

# Mount pseudo-filesystems for chroot
mount -t proc /proc "${ROOTFS_DIR}/proc"
mount -t sysfs /sys "${ROOTFS_DIR}/sys"
mount --bind /dev "${ROOTFS_DIR}/dev"
mount --bind /dev/pts "${ROOTFS_DIR}/dev/pts"

cleanup() {
    echo "[*] Cleaning up mounts..."
    umount -l "${ROOTFS_DIR}/proc" 2>/dev/null || true
    umount -l "${ROOTFS_DIR}/sys" 2>/dev/null || true
    umount -l "${ROOTFS_DIR}/dev/pts" 2>/dev/null || true
    umount -l "${ROOTFS_DIR}/dev" 2>/dev/null || true
}
trap cleanup EXIT

chroot "${ROOTFS_DIR}" /bin/bash << 'CHROOT_EOF'
export DEBIAN_FRONTEND=noninteractive

# Update apt
apt-get update

# Install developer packages
apt-get install -y --no-install-recommends \
    build-essential \
    gcc \
    g++ \
    gdb \
    clang \
    make \
    cmake \
    git \
    python3 \
    python3-pip \
    python3-venv \
    tmux \
    neovim \
    zsh \
    htop \
    tree \
    jq \
    ifupdown \
    rsync \
    pciutils \
    usbutils \
    libssl-dev

# Enable modern networking and disable legacy ifupdown
systemctl enable systemd-networkd 2>/dev/null || true
systemctl enable systemd-resolved 2>/dev/null || true
systemctl disable networking 2>/dev/null || true

# Generate locales
echo "en_US.UTF-8 UTF-8" > /etc/locale.gen
locale-gen
update-locale LANG=en_US.UTF-8

# Configure root password
echo "root:root" | chpasswd

# Create katusa user
useradd -m -s /bin/bash -G sudo,adm,dialout,cdrom,audio,video,plugdev katusa
echo "katusa:katusa" | chpasswd

# Copy skel files to katusa user home
cp -r /etc/skel/. /home/katusa/
chown -R katusa:katusa /home/katusa

# Configure sudoers (Passwordless sudo for convenience in VM)
echo "katusa ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/99-katusa
chmod 0440 /etc/sudoers.d/99-katusa

# Enable SSH root login with password (and katusa user)
sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config 2>/dev/null || true
sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config 2>/dev/null || true
systemctl enable ssh 2>/dev/null || true

# Enable serial getty for instant console login on QEMU
mkdir -p /etc/systemd/system/serial-getty@ttyS0.service.d
cat << 'AUTOLOGIN_S0' > /etc/systemd/system/serial-getty@ttyS0.service.d/autologin.conf
[Service]
ExecStart=
ExecStart=-/sbin/agetty -o '-p -- \\u' --keep-baud 115200,38400,9600 ttyS0 vt220
AUTOLOGIN_S0

mkdir -p /etc/systemd/system/serial-getty@ttyAMA0.service.d
cat << 'AUTOLOGIN_AMA0' > /etc/systemd/system/serial-getty@ttyAMA0.service.d/autologin.conf
[Service]
ExecStart=
ExecStart=-/sbin/agetty -o '-p -- \\u' --keep-baud 115200,38400,9600 ttyAMA0 vt220
AUTOLOGIN_AMA0

systemctl enable serial-getty@ttyS0.service 2>/dev/null || true
systemctl enable serial-getty@ttyAMA0.service 2>/dev/null || true

# Clean apt cache to reduce image size
apt-get clean
rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*
CHROOT_EOF

echo "[+] Step 5/6: Finalizing rootfs permissions and links..."
# Ensure init link
if [ ! -e "${ROOTFS_DIR}/sbin/init" ]; then
    ln -sf /lib/systemd/systemd "${ROOTFS_DIR}/sbin/init"
fi

echo "[+] Step 6/6: katusaOS RootFS successfully created at ${ROOTFS_DIR}!"
