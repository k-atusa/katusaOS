# Agent Operating Guidelines (에이전트 작업 원칙)

## Git Flow 브랜칭 전략 (1인 개발 최적화)

### 1. 일반 요청 (Daily Development)
- 기능 추가, UI 수정, 리팩터링, 스크립트 수정 등 모든 일반 개발 요청은 언제나 **`develop`** 브랜치에서 작업하고 커밋합니다.
- 1인 개발 환경이므로 별도의 `feature/` 브랜치는 생성하지 않습니다.

### 2. 배포 및 릴리즈 준비 (Release)
- 사용자가 "릴리즈 준비" 또는 "배포"를 요청할 때만 **`release/v*`** 브랜치를 `develop`에서 생성합니다.
- 버전 번호 확인, 문서 갱신 후 원격(origin)으로 `release/v*` 브랜치를 push합니다.
- **자동화된 배포 파이프라인**:
  1. GitHub Actions가 자동으로 multi-arch (amd64, arm64) 빌드 및 xz 압축을 수행합니다.
  2. **모든 빌드에 에러가 전혀 없을 때만** GitHub Actions가 자동으로:
     - `main` 브랜치로 merge
     - `vX.Y.Z` 버전 태그 생성
     - GitHub Release 발행 및 빌드 산출물(img.xz, iso, sha256) 자동 첨부
     - `develop` 브랜치로 main 변경 사항을 다시 merge하여 동기화
  3. **빌드 실패 시**: 태그나 Release가 일절 생성되지 않으므로 수동 삭제 작업이 불필요합니다. 버그를 `release/v*`에서 수정하여 다시 push하면 됩니다.
  4. (주의: 빌드 검증 전 수동으로 태그를 생성하거나 push하지 않습니다.)

### 3. 긴급 결함 수정 (Hotfix)
- 배포된 버전에 대한 긴급 버그 수정 요청 시 **`hotfix/v*`** 브랜치를 `main`에서 생성합니다.
- 버그 수정 후 원격으로 push하면 GitHub Actions가 빌드 검증 후 자동으로 `main` 머지, 태그 생성, Release 발행, `develop` 동기화를 완료합니다.

### 4. 메인 브랜치 보호 (Main Branch)
- `main` 브랜치는 배포된 릴리즈 태그(`v*`)가 위치하는 프로덕션 브랜치입니다.
- 직접 태그 push를 금지하며, GitHub Actions 파이프라인의 전 과정 무결성 검증을 통과한 빌드만 자동으로 머지 및 릴리즈됩니다.
