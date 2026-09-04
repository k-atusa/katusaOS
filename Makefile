# ==============================================================================
# katusaOS Makefile - Katusa Programming Club Dedicated Operating System
# ==============================================================================

SHELL := /bin/bash
ARCH ?= $(shell uname -m | sed -e 's/x86_64/amd64/' -e 's/aarch64/arm64/')

.PHONY: all help build-amd64 build-arm64 build run-amd64 run-arm64 run setup test clean

all: help

help:
	@echo "======================================================================"
	@echo " ★ katusaOS: Katusa Programming Club Custom OS Build & Test System ★"
	@echo "======================================================================"
	@echo "Targets:"
	@echo "  make setup          - Install host dependencies (QEMU, tools)"
	@echo "  make build          - Build OS image for host architecture ($(ARCH))"
	@echo "  make build-amd64    - Build katusaOS for amd64 (x86_64)"
	@echo "  make build-arm64    - Build katusaOS for arm64 (aarch64 / Apple Silicon)"
	@echo "  make run            - Run katusaOS in QEMU (Auto-detect host arch)"
	@echo "  make run-amd64      - Run katusaOS amd64 in QEMU"
	@echo "  make run-arm64      - Run katusaOS arm64 in QEMU"
	@echo "  make test           - Run local sanity tests on CLI and configs"
	@echo "  make clean          - Remove all build artifacts and disk images"
	@echo "======================================================================"

setup:
	@echo "[*] Setting up host environment..."
	./scripts/setup-host.sh

build:
	@echo "[*] Building katusaOS for architecture: $(ARCH)..."
	./docker/build-in-docker.sh $(ARCH)

build-amd64:
	@echo "[*] Building katusaOS (amd64)..."
	./docker/build-in-docker.sh amd64

build-arm64:
	@echo "[*] Building katusaOS (arm64)..."
	./docker/build-in-docker.sh arm64

run:
	@echo "[*] Booting katusaOS ($(ARCH)) in QEMU..."
	./scripts/run-qemu.sh --arch $(ARCH)

run-amd64:
	@echo "[*] Booting katusaOS (amd64) in QEMU..."
	./scripts/run-qemu.sh --arch amd64

run-arm64:
	@echo "[*] Booting katusaOS (arm64) in QEMU..."
	./scripts/run-qemu.sh --arch arm64

test:
	@echo "[*] Testing katusa CLI tool..."
	python3 ./packages/katusa-cli/katusa info
	python3 ./packages/katusa-cli/katusa doctor
	python3 ./packages/katusa-cli/katusa snippet cpp
	python3 ./packages/katusa-cli/katusa cheat git
	@echo "[*] Checking shell scripts syntax..."
	bash -n scripts/build-rootfs.sh
	bash -n scripts/build-image.sh
	bash -n scripts/run-qemu.sh
	bash -n scripts/setup-host.sh
	bash -n docker/build-in-docker.sh
	@echo "[✓] All static sanity checks passed!"

clean:
	@echo "[*] Cleaning build output..."
	rm -rf output/ build/
	@echo "[✓] Cleaned."
