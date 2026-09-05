# katusaOS 🚀
> **Katusa Programming Club 맞춤형 커스텀 Linux 운영체제**

![katusaOS Banner](https://img.shields.io/badge/katusaOS-v1.0%20(Vanguard)-00ADB5?style=for-the-badge)
![Arch](https://img.shields.io/badge/Architecture-amd64%20%7C%20arm64-brightgreen?style=for-the-badge)
![Base](https://img.shields.io/badge/Base-Debian%2012%20(Bookworm)-E95420?style=for-the-badge)
![License](https://img.shields.io/badge/License-GPLv3-blue?style=for-the-badge)

**katusaOS**는 Katusa Programming Club 멤버들의 학습, 알고리즘 문제 풀이, 시스템 프로그래밍, 풀스택 개발 및 프로젝트 빌드를 위해 특화 설계된 맞춤형 Linux 배포판입니다.

---

## 🌟 주요 특징

- **🚀 멀티 아키텍처 완전 지원**: `amd64` (x86_64) 및 `arm64` (aarch64 / Apple Silicon Mac) 네이티브 지원.
- **⚡ 초고속 QEMU 가상 머신 환경**: Direct Kernel Boot 및 하드웨어 가속기(macOS HVF / Linux KVM) 지원으로 수 초 만에 부팅 완료.
- **🛠️ 올인원 개발 툴체인 사전 탑재**:
  - **언어 & 컴파일러**: C/C++ (`gcc`, `g++`, `clang`), `make`, `cmake`, Python 3 (`pip`, `venv`), Rust, Go, Node.js, `git`
  - **디버깅 & 진단**: `gdb`, `lldb`, `htop`, `tree`, `jq`, `net-tools`
  - **터미널 & 에디터**: `zsh`, `tmux`, `neovim`, `vim`
- **💻 클럽 자체 개발 애플리케이션 (`katusa-cli`)**:
  - `katusa info`: 시스템 및 클럽 환경 정보 출력
  - `katusa doctor` / `katusa tools`: 설치된 개발 도구 현황 및 버전 자동 진단
  - `katusa snippet <cpp|python|rust|go|c>`: 알고리즘 및 프로젝트 스타터 코드 생성
  - `katusa cheat <git|tmux|gdb|qemu>`: 자주 사용하는 개발 명령어 치트시트
- **🎨 맞춤형 개발 환경 (Branding & Dotfiles)**:
  - 전용 ANSI ASCII 아트 및 동적 MOTD 배너
  - 최적화된 `.zshrc`, `.bashrc`, `.tmux.conf`, `.vimrc` 기본 적용
  - 기본 사용자: `katusa` (비밀번호: `katusa`, 비밀번호 없는 `sudo` 권한 포함)

---

## 📂 프로젝트 구조

```
katusaOS/
├── Makefile                       # 빌드 및 실행 명령어 통합 인터페이스
├── README.md                      # 프로젝트 소개 및 사용 가이드
├── configs/                       # OS 시스템 설정 및 브랜딩
│   ├── os-release                 # katusaOS 배포판 메타데이터
│   ├── hostname                   # 호스트명 설정 (katusaOS)
│   ├── issue                      # 시리얼 및 터미널 로그인 배너
│   ├── motd/                      # 로그인 MOTD 스크립트
│   └── skel/                      # 기본 유저 환경설정 (.bashrc, .zshrc, .tmux.conf, .vimrc)
├── packages/                      # 클럽 자체 개발 소프트웨어
│   └── katusa-cli/                # katusaOS 통합 CLI 관리 도구
│       └── katusa
├── scripts/                       # 자동화 빌드 & 실행 스크립트
│   ├── build-rootfs.sh            # debootstrap 기반 멀티아키텍처 rootfs 생성기
│   ├── build-image.sh             # ext4 디스크 이미지 패키징 및 커널/initrd 추출기
│   ├── run-qemu.sh                # QEMU 가상머신 런처 (HVF/KVM 가속, 포트포워딩)
│   └── setup-host.sh              # 호스트 개발 환경 의존성 설치 스크립트
└── docker/                        # 컨테이너 기반 격리 빌더
    ├── Dockerfile.builder         # 멀티아키텍처 OS 빌드용 Dockerfile
    └── build-in-docker.sh         # Docker 기반 OS 이미지 빌드 트리거
```

---

## 🚀 빠른 시작 가이드 (Quick Start)

### 1. 호스트 필수 도구 설치

katusaOS를 빌드하고 실행하려면 호스트 머신에 **Docker**와 **QEMU**가 필요합니다.

```bash
# 호스트 의존성 자동 설치 (macOS Homebrew 또는 Linux apt)
make setup
```

또는 수동 설치:
- **macOS**: `brew install qemu`
- **Ubuntu/Debian**: `sudo apt-get install qemu-system-x86 qemu-system-arm`

---

### 2. katusaOS 이미지 준비 (빌드 또는 릴리즈 다운로드)

#### 방법 A: GitHub Releases에서 사전 빌드된 압축 이미지 다운로드
GitHub [Releases](https://github.com/k-atusa/katusaOS/releases) 탭에서 최신 버전의 `katusaOS-<version>-<arch>.img.xz` 및 커널/initrd를 다운로드하여 바로 사용할 수 있습니다 (약 350MB).

```bash
# 다운로드 후 압축 해제 (output/ 디렉토리에 배치)
mkdir -p output
xz -d -k katusaOS-*-arm64.img.xz
mv katusaOS-*-arm64.img output/katusaOS-arm64.img
```

#### 방법 B: 로컬에서 Docker로 직접 빌드
Docker를 사용하여 호스트 OS에 구애받지 않고 안전하게 `amd64` 또는 `arm64` 이미지를 직접 빌드합니다.

```bash
# 호스트 아키텍처에 맞게 자동 빌드
make build

# 또는 특정 아키텍처 지정 빌드:
make build-arm64     # Apple Silicon Mac / ARM64 대상
make build-amd64     # x86_64 PC 대상
```

빌드가 완료되면 `output/` 디렉토리에 다음 파일들이 생성됩니다:
- `output/katusaOS-<arch>.img` (루트 파일시스템 디스크 이미지)
- `output/vmlinuz-<arch>` (Linux 커널 바이너리)
- `output/initrd-<arch>.img` (초기 RAM 디스크)

---

### 3. QEMU에서 katusaOS 부팅

빌드된 이미지를 QEMU 가상 머신으로 즉시 부팅합니다.

```bash
# 호스트 아키텍처에 맞추어 자동 실행
make run

# 또는 아키텍처 직접 지정:
make run-arm64       # ARM64 QEMU 실행 (Apple Silicon에서 -accel hvf로 네이티브 속도)
make run-amd64       # AMD64 QEMU 실행
```

#### QEMU 조작 팁:
- **로그인 계정**:
  - 기본 사용자: `katusa` / 비밀번호: `katusa`
  - root 사용자: `root` / 비밀번호: `root`
- **QEMU 콘솔 종료**: 키보드에서 `Ctrl + A`를 누른 후 `X`를 누릅니다.
- **SSH 접속**: 호스트 머신의 `2222`번 포트가 게스트 머신의 `22`번 포트로 포워딩됩니다.
  ```bash
  ssh -p 2222 katusa@localhost
  ```

---

## 🛠️ 자체 개발 도구: `katusa` CLI

OS 내부 터미널에서 `katusa` 명령어를 통해 다양한 클럽 전용 기능을 사용할 수 있습니다.

```bash
# 1. katusaOS 시스템 및 클럽 정보 확인
katusa info

# 2. 컴파일러 및 개발 도구 체계 진단
katusa doctor

# 3. 알고리즘 문제 풀이 스타터 템플릿 생성 (C++, Python, Rust, Go, C 지원)
katusa snippet cpp -o solution.cpp
katusa snippet python -o solution.py

# 4. Git, Tmux, GDB 치트시트 열람
katusa cheat git
katusa cheat tmux
katusa cheat gdb
```

---

## 🧪 테스트 및 무결성 검증

로컬에서 CLI 기능 및 스크립트 문법 무결성을 검증하려면:

```bash
make test
```

빌드 산출물을 정리하려면:

```bash
make clean
```

---

## 🤝 기여 (Contributing)

Katusa Programming Club 멤버 누구나 새로운 패키지, dotfile 템플릿, 유틸리티 스크립트를 추가할 수 있습니다. Pull Request 또는 이슈를 등록해 주세요!