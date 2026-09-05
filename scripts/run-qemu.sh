#!/usr/bin/env bash
# katusaOS QEMU Launcher
# Multi-architecture boot runner (amd64, arm64)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
OUTPUT_DIR="${REPO_ROOT}/output"

# Defaults
ARCH="arm64"
HOST_ARCH="$(uname -m)"
HOST_OS="$(uname -s)"

# Auto-detect default arch based on host
if [ "${HOST_ARCH}" = "x86_64" ]; then
    ARCH="amd64"
elif [ "${HOST_ARCH}" = "arm64" ] || [ "${HOST_ARCH}" = "aarch64" ]; then
    ARCH="arm64"
fi

MEM="${MEM:-2048M}"
SMP="${SMP:-2}"
SSH_PORT="${SSH_PORT:-2222}"
MODE="nographic"
BOOT_MODE="direct" # direct (kernel+initrd+disk) or disk

print_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -a, --arch <amd64|arm64>  Target architecture (default: ${ARCH})"
    echo "  -m, --mem <size>          RAM allocation (default: ${MEM})"
    echo "  -c, --cpu <count>         vCPU count (default: ${SMP})"
    echo "  -p, --port <port>         Host SSH forwarded port (default: ${SSH_PORT})"
    echo "  --gui                     Launch QEMU with graphical window instead of serial console"
    echo "  --nographic               Serial terminal console mode (default)"
    echo "  -h, --help                Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 --arch arm64"
    echo "  $0 --arch amd64 --gui"
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        -a|--arch)
            ARCH="$2"
            shift 2
            ;;
        -m|--mem)
            MEM="$2"
            shift 2
            ;;
        -c|--cpu)
            SMP="$2"
            shift 2
            ;;
        -p|--port)
            SSH_PORT="$2"
            shift 2
            ;;
        --gui)
            MODE="gui"
            shift
            ;;
        --nographic)
            MODE="nographic"
            shift
            ;;
        -h|--help)
            print_usage
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            print_usage
            exit 1
            ;;
    esac
done

echo "[+] ========================================================"
echo "[+] Starting katusaOS QEMU Virtual Machine"
echo "[+] Target Arch:  ${ARCH}"
echo "[+] Memory:       ${MEM}"
echo "[+] vCPUs:        ${SMP}"
echo "[+] SSH Forward:  localhost:${SSH_PORT} -> guest:22"
echo "[+] Display Mode: ${MODE}"
echo "[+] ========================================================"

# Verify artifacts exist
DISK_IMG="${OUTPUT_DIR}/katusaOS-${ARCH}.img"
KERNEL_IMG="${OUTPUT_DIR}/vmlinuz-${ARCH}"
INITRD_IMG="${OUTPUT_DIR}/initrd-${ARCH}.img"

if [ ! -f "${DISK_IMG}" ]; then
    echo "[-] Error: Disk image not found at ${DISK_IMG}"
    echo "[-] Please build it first with: make build-${ARCH}"
    exit 1
fi

# Determine QEMU Binary & Arguments based on Arch and Host
QEMU_BIN=""
QEMU_ACCEL=""
QEMU_EXTRA_ARGS=()
BOOT_ARGS=""

if [ "${ARCH}" = "amd64" ]; then
    QEMU_BIN="qemu-system-x86_64"
    CONSOLE="ttyS0"
    
    # Check accelerator
    if [ "${HOST_OS}" = "Darwin" ] && [ "${HOST_ARCH}" = "x86_64" ]; then
        QEMU_ACCEL="-accel hvf"
        QEMU_CPU="-cpu host"
    elif [ "${HOST_OS}" = "Linux" ] && [ -e /dev/kvm ] && [ "${HOST_ARCH}" = "x86_64" ]; then
        QEMU_ACCEL="-accel kvm"
        QEMU_CPU="-cpu host"
    else
        QEMU_ACCEL="-accel tcg"
        QEMU_CPU="-cpu max"
    fi

    QEMU_MACHINE="-machine q35"
    QEMU_EXTRA_ARGS+=(
        "-device" "virtio-net-pci,netdev=net0"
        "-drive" "file=${DISK_IMG},format=raw,if=virtio,id=drive0"
    )

elif [ "${ARCH}" = "arm64" ]; then
    QEMU_BIN="qemu-system-aarch64"
    CONSOLE="ttyAMA0"

    # Check accelerator
    if [ "${HOST_OS}" = "Darwin" ] && ([ "${HOST_ARCH}" = "arm64" ] || [ "${HOST_ARCH}" = "aarch64" ]); then
        QEMU_ACCEL="-accel hvf"
        QEMU_CPU="-cpu host"
    elif [ "${HOST_OS}" = "Linux" ] && [ -e /dev/kvm ] && ([ "${HOST_ARCH}" = "arm64" ] || [ "${HOST_ARCH}" = "aarch64" ]); then
        QEMU_ACCEL="-accel kvm"
        QEMU_CPU="-cpu host"
    else
        QEMU_ACCEL="-accel tcg"
        QEMU_CPU="-cpu cortex-a57"
    fi

    QEMU_MACHINE="-machine virt,highmem=on"
    QEMU_EXTRA_ARGS+=(
        "-device" "virtio-net-pci,netdev=net0"
        "-drive" "file=${DISK_IMG},format=raw,if=virtio,id=drive0"
    )
else
    echo "[-] Error: Unsupported architecture ${ARCH}"
    exit 1
fi

# Check if QEMU binary is installed
if ! command -v "${QEMU_BIN}" &> /dev/null; then
    echo "[-] Error: ${QEMU_BIN} is not installed or not found in PATH."
    echo "[-] To install QEMU:"
    if [ "${HOST_OS}" = "Darwin" ]; then
        echo "    brew install qemu"
    else
        echo "    sudo apt-get install qemu-system-x86 qemu-system-arm"
    fi
    exit 1
fi

# Network configuration with SSH port forwarding
NET_ARGS=(
    "-netdev" "user,id=net0,hostfwd=tcp::${SSH_PORT}-:22"
)

# Display / Console mode
if [ "${MODE}" = "nographic" ]; then
    DISPLAY_ARGS=("-nographic")
    KERNEL_APPEND="modules=ext4,virtio_pci,virtio_blk root=/dev/vda rootfstype=ext4 rw console=${CONSOLE} quiet"
else
    DISPLAY_ARGS=("-device" "virtio-gpu-pci" "-display" "default")
    KERNEL_APPEND="modules=ext4,virtio_pci,virtio_blk root=/dev/vda rootfstype=ext4 rw console=${CONSOLE} console=tty1 quiet"
fi

# Direct kernel boot args if kernel & initrd exist
if [ -f "${KERNEL_IMG}" ] && [ -f "${INITRD_IMG}" ]; then
    BOOT_ARGS=(
        "-kernel" "${KERNEL_IMG}"
        "-initrd" "${INITRD_IMG}"
        "-append" "${KERNEL_APPEND}"
    )
else
    BOOT_ARGS=()
fi

echo "[+] Booting katusaOS with command:"
echo "    ${QEMU_BIN} ${QEMU_MACHINE} ${QEMU_ACCEL} ${QEMU_CPU} -m ${MEM} -smp ${SMP} ..."
echo ""
if [ "${MODE}" = "nographic" ]; then
    echo "[!] Tip: Press 'Ctrl+A' then 'X' to terminate the QEMU session."
fi
echo "[!] SSH Access: ssh -p ${SSH_PORT} katusa@localhost (Password: katusa)"
echo "------------------------------------------------------------"

exec "${QEMU_BIN}" \
    ${QEMU_MACHINE} \
    ${QEMU_ACCEL} \
    ${QEMU_CPU} \
    -m "${MEM}" \
    -smp "${SMP}" \
    "${NET_ARGS[@]}" \
    "${DISPLAY_ARGS[@]}" \
    "${BOOT_ARGS[@]}" \
    "${QEMU_EXTRA_ARGS[@]}"
