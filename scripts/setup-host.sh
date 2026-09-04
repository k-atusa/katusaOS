#!/usr/bin/env bash
# katusaOS Host Dependencies Setup Helper
set -euo pipefail

HOST_OS="$(uname -s)"
echo "[+] Detecting host system: ${HOST_OS} ($(uname -m))"

if [ "${HOST_OS}" = "Darwin" ]; then
    echo "[+] Checking macOS dependencies..."
    if ! command -v brew &> /dev/null; then
        echo "[-] Homebrew is not installed. Please install it from https://brew.sh"
        exit 1
    fi

    echo "[+] Installing QEMU and virtualization tools via Homebrew..."
    brew install qemu
    echo "[+] Homebrew tools installed successfully!"

elif [ "${HOST_OS}" = "Linux" ]; then
    echo "[+] Checking Linux dependencies..."
    if command -v apt-get &> /dev/null; then
        echo "[+] Installing QEMU and build tools via apt..."
        sudo apt-get update
        sudo apt-get install -y \
            qemu-system-x86 \
            qemu-system-arm \
            qemu-user-static \
            binfmt-support \
            debootstrap \
            e2fsprogs \
            dosfstools \
            rsync \
            make \
            curl
        echo "[+] Linux packages installed successfully!"
    else
        echo "[!] Unsupported Linux package manager. Please install QEMU manually."
    fi
fi

echo "[+] Setup completed! You can now build and run katusaOS."
