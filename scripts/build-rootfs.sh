#!/usr/bin/env bash
# katusaOS Alpine-based Rootfs Build Script (apk package manager)
# Supports: amd64 (x86_64), arm64 (aarch64)
set -euo pipefail

ARCH="${1:-arm64}"
ROOTFS_DIR="${2:-/tmp/katusa-build-${ARCH}/rootfs}"
ALPINE_BRANCH="${ALPINE_BRANCH:-v3.20}"
ALPINE_MIRROR="${ALPINE_MIRROR:-https://dl-cdn.alpinelinux.org/alpine}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Map ARCH to Alpine architecture
case "${ARCH}" in
    amd64|x86_64)
        ALPINE_ARCH="x86_64"
        ARCH="amd64"
        ;;
    arm64|aarch64)
        ALPINE_ARCH="aarch64"
        ARCH="arm64"
        ;;
    *)
        echo "[-] Error: Unsupported architecture '${ARCH}'. Use 'amd64' or 'arm64'."
        exit 1
        ;;
esac

echo "[+] ========================================================"
echo "[+] Building katusaOS RootFS (Alpine Linux / apk)"
echo "[+] Target Architecture: ${ARCH} (${ALPINE_ARCH})"
echo "[+] Alpine Branch:       ${ALPINE_BRANCH}"
echo "[+] Alpine Mirror:       ${ALPINE_MIRROR}"
echo "[+] RootFS Directory:    ${ROOTFS_DIR}"
echo "[+] ========================================================"

# Ensure root privileges
if [ "$(id -u)" -ne 0 ]; then
    echo "[-] Error: This script must be run as root (or inside Docker)."
    exit 1
fi

# Clean up existing rootfs dir
rm -rf "${ROOTFS_DIR}"
mkdir -p "${ROOTFS_DIR}/etc/apk"

# Step 1: Configure APK Repositories and Keys
echo "[+] Step 1/6: Setting up APK repositories and keys..."
cat << EOF > "${ROOTFS_DIR}/etc/apk/repositories"
${ALPINE_MIRROR}/${ALPINE_BRANCH}/main
${ALPINE_MIRROR}/${ALPINE_BRANCH}/community
EOF

# Copy host apk keys
if [ -d /etc/apk/keys ]; then
    cp -r /etc/apk/keys "${ROOTFS_DIR}/etc/apk/"
else
    mkdir -p "${ROOTFS_DIR}/etc/apk/keys"
    curl -sSL "https://alpinelinux.org/keys/alpine-devel@lists.alpinelinux.org-6165ee59.rsa.pub" \
        -o "${ROOTFS_DIR}/etc/apk/keys/alpine-devel@lists.alpinelinux.org-6165ee59.rsa.pub" || true
fi

# Step 2: Bootstrap Alpine Base and Kernel using apk.static
echo "[+] Step 2/6: Bootstrapping Alpine base system for ${ALPINE_ARCH}..."

BASE_PACKAGES=(
    alpine-base
    openrc
    busybox
    linux-virt
    util-linux
    coreutils
    bash
    shadow
    sudo
    openssh
    ca-certificates
    curl
    wget
    tar
    xz
    e2fsprogs
)

DEVELOPER_PACKAGES=(
    build-base
    gcc
    g++
    make
    cmake
    clang
    gdb
    git
    python3
    py3-pip
    rust
    cargo
    go
    nodejs
    npm
    tmux
    neovim
    vim
    zsh
    htop
    tree
    jq
    net-tools
    bind-tools
)

ALL_PACKAGES=("${BASE_PACKAGES[@]}" "${DEVELOPER_PACKAGES[@]}")

# Find apk binary (apk.static preferred, fallback to apk)
APK_BIN="$(command -v apk.static || command -v apk)"
if [ -z "${APK_BIN}" ]; then
    echo "[-] Error: apk or apk.static not found!"
    exit 1
fi

"${APK_BIN}" \
    --arch "${ALPINE_ARCH}" \
    --root "${ROOTFS_DIR}" \
    --keys-dir "${ROOTFS_DIR}/etc/apk/keys" \
    --repositories-file "${ROOTFS_DIR}/etc/apk/repositories" \
    --initdb add "${ALL_PACKAGES[@]}"

echo "[+] Step 3/6: Copying katusaOS configurations and packages..."

# Inject custom OS identity
cp "${REPO_ROOT}/configs/os-release" "${ROOTFS_DIR}/etc/os-release"
cp "${REPO_ROOT}/configs/hostname" "${ROOTFS_DIR}/etc/hostname"
cp "${REPO_ROOT}/configs/issue" "${ROOTFS_DIR}/etc/issue"
cp "${REPO_ROOT}/configs/issue" "${ROOTFS_DIR}/etc/issue.net"

# Copy MOTD banner (Alpine prints /etc/motd upon login)
mkdir -p "${ROOTFS_DIR}/etc"
cat << 'EOF' > "${ROOTFS_DIR}/etc/motd"

  _  __      _                     ___  ____  
 | |/ /__ _ | |_ _   _ ___  __ _  / _ \/ ___| 
 | ' // _` || __| | | / __|/ _` || | | \___ \ 
 | . \ (_| || |_| |_| \__ \ (_| || |_| |___) |
 |_|\_\__,_| \__|\__,_|___/\__,_| \___/|____/ 
  ★ Katusa Programming Club Dedicated Operating System ★

Welcome to katusaOS! Type 'katusa doctor' to verify your toolchains,
or 'katusa help' for developer cheat sheets & starter templates.

EOF

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
Welcome to katusaOS (Alpine Linux + APK edition)!
Katusa Programming Club Dedicated Operating System.

Check out 'katusa --help' for CLI utilities and starter templates.
EOF

echo "[+] Step 4/6: Configuring network, mounts, and inittab..."

# DNS Resolver
cat << 'EOF' > "${ROOTFS_DIR}/etc/resolv.conf"
nameserver 1.1.1.1
nameserver 8.8.8.8
EOF

# Network interfaces (DHCP for eth0)
cat << 'EOF' > "${ROOTFS_DIR}/etc/network/interfaces"
auto lo
iface lo inet loopback

auto eth0
iface eth0 inet dhcp
EOF

# Hosts file
cat << 'EOF' > "${ROOTFS_DIR}/etc/hosts"
127.0.0.1   localhost
127.0.1.1   katusaOS

::1         localhost ip6-localhost ip6-loopback
ff02::1     ip6-allnodes
ff02::2     ip6-allrouters
EOF

# fstab
cat << 'EOF' > "${ROOTFS_DIR}/etc/fstab"
# /etc/fstab: static file system information.
/dev/vda        /               ext4    noatime,rw       0       1
tmpfs           /tmp            tmpfs   defaults          0       0
EOF

# inittab: Configure serial gettys for instant console login on QEMU
cat << 'EOF' > "${ROOTFS_DIR}/etc/inittab"
# /etc/inittab
::sysinit:/sbin/openrc sysinit
::sysinit:/sbin/openrc boot
::wait:/sbin/openrc default

# Set up a generic prompt on the serial ports
ttyS0::respawn:/sbin/getty -L 115200 ttyS0 vt100
ttyAMA0::respawn:/sbin/getty -L 115200 ttyAMA0 vt100
tty1::respawn:/sbin/getty 38400 tty1

# Stuff to do for the 3-finger salute
::ctrlaltdel:/sbin/reboot

# Stuff to do before rebooting
::shutdown:/sbin/openrc shutdown
EOF

echo "[+] Step 5/6: Configuring OpenRC services and users inside chroot..."

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

# Chroot execution for OpenRC & user setup
chroot "${ROOTFS_DIR}" /bin/sh << 'CHROOT_EOF'
set -e

# Set root password
echo "root:root" | chpasswd

# Create katusa user
adduser -D -s /bin/bash -g "katusa" katusa
echo "katusa:katusa" | chpasswd
addgroup katusa wheel

# Copy skel files to katusa home
cp -r /etc/skel/. /home/katusa/
chown -R katusa:katusa /home/katusa

# Configure sudoers for wheel
mkdir -p /etc/sudoers.d
echo "%wheel ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/wheel
chmod 0440 /etc/sudoers.d/wheel

# Configure SSH daemon
mkdir -p /etc/ssh
ssh-keygen -A 2>/dev/null || true
sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config 2>/dev/null || true
sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config 2>/dev/null || true

# Register OpenRC services
rc-update add devfs sysinit 2>/dev/null || true
rc-update add dmesg sysinit 2>/dev/null || true
rc-update add mdev sysinit 2>/dev/null || true
rc-update add hwdrivers sysinit 2>/dev/null || true

rc-update add bootmisc boot 2>/dev/null || true
rc-update add hostname boot 2>/dev/null || true
rc-update add modules boot 2>/dev/null || true
rc-update add networking boot 2>/dev/null || true
rc-update add seedrng boot 2>/dev/null || true
rc-update add urandom boot 2>/dev/null || true
rc-update add sysctl boot 2>/dev/null || true

rc-update add sshd default 2>/dev/null || true
rc-update add local default 2>/dev/null || true

rc-update add killprocs shutdown 2>/dev/null || true
rc-update add savecache shutdown 2>/dev/null || true
rc-update add mount-ro shutdown 2>/dev/null || true
CHROOT_EOF

echo "[+] Step 6/6: katusaOS RootFS successfully created at ${ROOTFS_DIR}!"
