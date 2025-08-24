# VS Code 설정 가이드 - Kubernetes Patterns 프로젝트

## 📍 현재 설정 위치

VS Code 설정이 프로젝트 루트에 올바르게 설치되어 있습니다:

```bash
/Users/kikim/githubProjects/kubernetes-patterns/.vscode/
```

## 🚀 VS Code에서 사용하는 방법

### 1. VS Code 열기

```bash
# 프로젝트 루트에서 VS Code 실행
cd /Users/kikim/githubProjects/kubernetes-patterns
code .
```

### 2. 권장 확장 프로그램 설치

VS Code를 열면 우측 하단에 "이 작업 영역에 권장 확장이 있습니다" 알림이 표시됩니다.

- **"모두 설치"** 클릭

또는 수동 설치:

1. `Cmd+Shift+X` (확장 마켓플레이스 열기)
2. 다음 확장 설치:
   - `ms-kubernetes-tools.vscode-kubernetes-tools`
   - `redhat.vscode-yaml`
   - `trunk.io`
   - `ms-azuretools.vscode-docker`
   - `ipedrazas.kubernetes-snippets`

### 3. 설정 확인

설정이 자동으로 적용되었는지 확인:

1. `Cmd+,` (설정 열기)
2. 우측 상단 `{}` 아이콘 클릭 (JSON 보기)
3. Workspace 설정에 다음 항목 확인:
   - `yaml.schemas`
   - `yaml.validate`
   - `kubernetes.validate`

## 📁 프로젝트 구조와 설정

```bash
kubernetes-patterns/
├── .vscode/                     # VS Code 설정 (여기!)
│   ├── settings.json            # 에디터 설정
│   ├── tasks.json              # 자동화 작업
│   ├── extensions.json         # 권장 확장
│   ├── keybindings.json        # 단축키
│
└── foundational/               # 패턴 디렉토리
    ├── declarative-deployment/
    │   ├── .kube-linter.yaml
    │   └── k8s/
    ├── managed-lifecycle/
    │   ├── .kube-linter.yaml
    │   └── k8s/
    └── health-probe/
        ├── .kube-linter.yaml
        └── k8s/
```

## ⌨️ 단축키 사용법

| 단축키 | 기능 | 사용 위치 |
|--------|------|----------|
| `Cmd+K Cmd+L` | 현재 파일 린팅 | YAML 파일 |
| `Cmd+K Cmd+F` | 자동 수정 | YAML 파일 |
| `Cmd+K Cmd+A` | 모든 이슈 표시 | YAML 파일 |
| `Cmd+K Cmd+P` | 패턴 전체 린팅 | 어디서나 |

### 단축키 테스트

1. YAML 파일 열기:

   ```bash
   # 예시 파일 열기
   code foundational/declarative-deployment/apps/rolling-update/deployment.yaml
   ```

2. 린팅 실행:
   - `Cmd+K` 누른 후 `Cmd+L` → 터미널에 린팅 결과 표시

3. 모든 이슈 확인:
   - `Cmd+K` 누른 후 `Cmd+A` → 기존 이슈 포함 표시

## 🎯 Task 실행 방법

### 방법 1: 명령 팔레트

1. `Cmd+Shift+P` (명령 팔레트 열기)
2. `Tasks: Run Task` 입력
3. 원하는 작업 선택:
   - Lint Current File
   - Fix Current File
   - Lint All Pattern Files
   - Show All Issues

### 방법 2: 단축키 사용

위의 단축키 섹션 참조

### 방법 3: 터미널에서 직접

```bash
# VS Code 통합 터미널에서 (Ctrl+`)
trunk check foundational/declarative-deployment/k8s/*.yaml
```

## 🔧 문제 해결

### 1. 단축키가 작동하지 않음

**해결 방법:**

1. `Cmd+K Cmd+S` (키보드 단축키 열기)
2. "Lint Current File" 검색
3. 기존 바인딩 확인 및 수정

### 2. YAML 자동완성이 안 됨

**해결 방법:**

1. YAML 확장이 설치되었는지 확인
2. 파일 확장자가 `.yaml` 또는 `.yml`인지 확인
3. 우측 하단 언어 모드가 "YAML"인지 확인

### 3. Trunk 명령을 찾을 수 없음

**해결 방법:**

```bash
# Trunk 설치 확인
which trunk

# 설치 안 되어 있으면
curl https://get.trunk.io -fsSL | bash

# VS Code 재시작
```
