# katusaOS 🚀
> **Dedicated Custom Linux Operating System for the Katusa Programming Club**

![katusaOS Banner](https://img.shields.io/badge/katusaOS-v0.1.1--alpha-00ADB5?style=for-the-badge)
![Arch](https://img.shields.io/badge/Architecture-amd64%20%7C%20arm64-brightgreen?style=for-the-badge)
![Base](https://img.shields.io/badge/Base-Alpine%20Linux%203.20-0D597F?style=for-the-badge)
![Pkg Manager](https://img.shields.io/badge/Pkg%20Manager-apk-blueviolet?style=for-the-badge)
![License](https://img.shields.io/badge/License-GPLv3-blue?style=for-the-badge)

**katusaOS** is a lightweight, high-performance, and reproducible Linux distribution built on **Alpine Linux** and the **`apk`** package manager, tailored for members of the **Katusa Programming Club**. It comes pre-configured with modern developer toolchains, algorithm problem-solving starter templates, and club-developed utilities (`katusa-cli`, custom dynamic MOTD, shell configurations).

---

## 🌟 Key Features

- **🚀 Full Multi-Architecture Support**: Native support for both `amd64` (x86_64) and `arm64` (aarch64 / Apple Silicon Mac).
- **⚡ Blazing Fast QEMU Virtual Machine**: Boots in under a second using direct kernel boot and hardware accelerators (macOS HVF / Linux KVM).
- **🛠️ All-in-One Developer Toolchain Pre-installed**:
  - **Languages & Compilers**: C/C++ (`gcc`, `g++`, `clang`), `make`, `cmake`, Python 3 (`pip`, `venv`), Rust, Go, Node.js, `git`.
  - **Debugging & Diagnostics**: `gdb`, `lldb`, `htop`, `tree`, `jq`, `net-tools`.
  - **Terminal & Editors**: `zsh`, `tmux`, `neovim`, `vim`.
- **💻 Club-Developed CLI Tool (`katusa`)**:
  - `katusa info`: Display OS version, kernel, architecture, and club info.
  - `katusa doctor` / `katusa tools`: Automated health check for installed compilers and tools.
  - `katusa snippet <cpp|python|rust|go|c>`: Instant algorithm and project boilerplate generator.
  - `katusa cheat <git|tmux|gdb|qemu>`: Quick command reference and cheat sheets.
  - `katusa help`: Built-in CLI guide.
- **🎨 Tailored Developer Environment (Branding & Dotfiles)**:
  - Clean pre-login prompt (`katusaOS 0.1.1-alpha (ttyAMA0)`).
  - Dynamic post-login MOTD with club greeting.
  - Optimized `.zshrc`, `.bashrc`, `.tmux.conf`, and `.vimrc` configurations.
  - Default user: `katusa` (password: `katusa`, passwordless `sudo` privileges).

---

## 📂 Project Directory Structure

```
katusaOS/
├── .github/workflows/             # CI/CD Workflows
│   └── release.yml                # Automated multi-arch build & xz release asset publisher
├── Makefile                       # Unified build and execution command interface
├── README.md                      # Project documentation and user guide
├── configs/                       # OS system configuration & branding
│   ├── os-release                 # katusaOS distribution metadata
│   ├── hostname                   # Hostname configuration (katusaOS)
│   ├── issue                      # Clean serial and tty pre-login banner
│   ├── motd/                      # Dynamic post-login MOTD scripts
│   └── skel/                      # Default user dotfiles (.bashrc, .zshrc, .tmux.conf, .vimrc)
├── packages/                      # Club-developed applications
│   └── katusa-cli/                # katusaOS unified CLI tool
│       └── katusa
├── scripts/                       # Automation build & run scripts
│   ├── build-rootfs.sh            # Debootstrap-based multi-arch rootfs generator
│   ├── build-image.sh             # ext4 disk image packager and kernel/initrd extractor
│   ├── run-qemu.sh                # QEMU launcher (HVF/KVM accel, SSH port forward)
│   └── setup-host.sh              # Host dependency installer script
└── docker/                        # Isolated builder container
    ├── Dockerfile.builder         # Multi-arch builder Dockerfile
    └── build-in-docker.sh         # Docker build runner script
```

---

## 🚀 Quick Start Guide

### 1. Install Host Prerequisites

To build and run katusaOS, your host machine requires **Docker** and **QEMU**.

```bash
# Automatically install host dependencies (macOS Homebrew or Linux apt)
make setup
```

Or install manually:
- **macOS**: `brew install qemu`
- **Ubuntu/Debian**: `sudo apt-get install qemu-system-x86 qemu-system-arm`

---

### 2. Obtain the katusaOS Image (Download or Build)

#### Method A: Download Pre-built Compressed Image from GitHub Releases (Recommended)
Download the latest `katusaOS-<version>-<arch>.img.xz` and kernel/initrd bundle from the GitHub [Releases](https://github.com/k-atusa/katusaOS/releases) page (~350MB).

```bash
# Download and decompress into the output/ directory (takes ~10 seconds)
mkdir -p output
xz -d -k katusaOS-*-arm64.img.xz
mv katusaOS-*-arm64.img output/katusaOS-arm64.img
```

#### Method B: Build Locally via Docker
Build the complete rootfs and disk image locally using the isolated Docker builder:

```bash
# Auto-detect host architecture and build
make build

# Or build for a specific target architecture:
make build-arm64     # Target: Apple Silicon Mac / ARM64
make build-amd64     # Target: x86_64 PC
```

Once the build finishes, artifacts are placed in the `output/` directory:
- `output/katusaOS-<arch>.img` (4GB ext4 root filesystem disk image)
- `output/vmlinuz-<arch>` (Linux kernel binary)
- `output/initrd-<arch>.img` (Initial RAM disk)

---

### 3. Boot katusaOS in QEMU

Boot the virtual machine directly into an interactive terminal session:

```bash
# Auto-detect host architecture and launch QEMU
make run

# Or launch for a specific architecture:
make run-arm64       # ARM64 QEMU (Native speed via -accel hvf on Apple Silicon)
make run-amd64       # AMD64 QEMU
```

#### QEMU Tips & Credentials:
- **Default Credentials**:
  - User: `katusa` / Password: `katusa` (has full `sudo` privileges)
  - Root: `root` / Password: `root`
- **Exit QEMU Console**: Press `Ctrl + A` and then press `X`.
- **SSH Access**: Host port `2222` is automatically forwarded to guest port `22`:
  ```bash
  ssh -p 2222 katusa@localhost
  ```

---

### 4. Running in UTM App & Permanent Disk Installation (`katusa-install`)

katusaOS provides a dedicated interactive **Terminal UI Installer (`katusa-install`)** supporting both modern **GPT (UEFI)** and legacy **MBR (Legacy BIOS)** environments for virtualization apps like **UTM (macOS / iOS)**, **QEMU**, and physical drives.

#### Method 1: Installing to Virtual Disk via Bootable ISO (Recommended for UTM / QEMU)
1. In UTM, click **`+` (Create VM) -> Virtualize -> Linux**.
2. Check **Boot ISO Image** and select `output/katusaOS-arm64-installer.iso` (or `amd64`).
3. Set your desired disk size (e.g., 20GB - 64GB) and finish creating the VM.
4. Start the VM. It boots into the katusaOS live environment.
5. In the terminal, run the interactive installer:
   ```bash
   katusa-install
   ```
6. The installer TUI will guide you through:
   - Target disk selection (e.g. `/dev/vda` 64GB)
   - Partition scheme & bootloader selection:
     - **GPT (UEFI)**: Modern GUID partition table with FAT32 ESP partition and UEFI bootloader.
     - **MBR (Legacy BIOS)**: Classic MS-DOS partition table with active boot flag and MBR BIOS bootloader.
   - Formatting and copying system files
   - Generating system configuration and `/etc/fstab`
7. Once installation finishes:
   - **VM Environment**: Detach/remove the installer ISO from VM settings and reboot.
   - **USB Boot / Physical Drive**: Detach the installation media and reboot.

#### Method 2: Booting the GPT Disk Image Directly in UTM
1. In UTM, create a Linux VM without an ISO.
2. In the VM settings under **Drives**, add or import `output/katusaOS-arm64.img`.
3. Start the VM — UTM's UEFI firmware (`EDK2/AAVMF`) automatically boots GRUB EFI from the disk!

---

## 🛠️ Club Tool: `katusa` CLI

Inside the katusaOS terminal, you can access club tools and utilities with the `katusa` command:

```bash
# 1. View system and club info
katusa info

# 2. Run developer toolchain and environment diagnostics
katusa doctor

# 3. Generate starter code templates (supports C++, Python, Rust, Go, C)
katusa snippet cpp -o solution.cpp
katusa snippet python -o solution.py

# 4. Access quick cheat sheets
katusa cheat git
katusa cheat tmux
katusa cheat gdb
katusa cheat qemu

# 5. Display general CLI help
katusa help
```

---

## 🧪 Testing & Verification

Run local sanity tests on CLI tools and check shell script syntax:

```bash
make test
```

To clean up build artifacts:

```bash
make clean
```

---

## 🔄 CI/CD & Automated Releases

A GitHub Actions workflow (`.github/workflows/release.yml`) automatically triggers upon publishing a new release:
1. Checks out the `main` branch.
2. Builds both `amd64` and `arm64` images in parallel.
3. Compresses the raw 4GB images using multi-threaded `xz` (~350MB).
4. Generates SHA256 checksums (`.sha256`).
5. Uploads `katusaOS-<version>-<arch>.img.xz` and kernel bundles directly to the GitHub Release.

---

## 🤝 Contributing

All members of the Katusa Programming Club are welcome to contribute! You can add new package presets, dotfile configurations, or CLI subcommands. Feel free to open an issue or submit a Pull Request.

---

## 📄 License

This project is licensed under the [GNU General Public License v3.0](LICENSE).