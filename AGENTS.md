# Agent Operating Guidelines (에이전트 작업 원칙)

## Git Flow 브랜칭 전략 (1인 개발 최적화)

### 1. 일반 요청 (Daily Development)
- 기능 추가, UI 수정, 리팩터링, 스크립트 수정 등 모든 일반 개발 요청은 언제나 **`develop`** 브랜치에서 작업하고 커밋합니다.
- 1인 개발 환경이므로 별도의 `feature/` 브랜치는 생성하지 않습니다.

### 2. 배포 및 릴리즈 준비 (Release)
- 사용자가 "릴리즈 준비" 또는 "배포"를 요청할 때만 **`release/v*`** 브랜치를 `develop`에서 생성합니다.
- 버전 번호 확인, 문서 갱신, 최종 점검 후:
  1. `main` 브랜치에 merge
  2. 버전 태그(`vX.Y.Z`)를 `main` 브랜치에 생성
  3. `develop` 브랜치에 다시 merge하여 동기화 완료

### 3. 긴급 결함 수정 (Hotfix)
- 배포된 버전에 대한 긴급 버그 수정 요청 시 **`hotfix/v*`** 브랜치를 `main`에서 생성합니다.
- 버그 수정 완료 후:
  1. `main` 브랜치에 merge 및 패치 버전 태그 생성
  2. `develop` 브랜치에도 merge하여 변경 사항 유지

### 4. 메인 브랜치 보호 (Main Branch)
- `main` 브랜치는 실제 배포 태그(`v*`)가 위치하는 프로덕션 브랜치입니다.
- 직접 커밋을 지양하고, `release/v*` 또는 `hotfix/v*` 브랜치로부터의 merge로만 갱신합니다.
