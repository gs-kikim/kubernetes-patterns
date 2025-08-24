# 쿠버네티스 패턴 린팅 가이드

"쿠버네티스 패턴" 스터디를 위한 린팅 가이드입니다. 각 패턴별로 다른 린팅 규칙을 적용하고, 실제 검증된 명령어와 해결 방법을 제공합니다.

## 🚀 빠른 시작

### 1. 사전 준비사항

```bash
# Trunk 설치
curl https://get.trunk.io -fsSL | bash

# 프로젝트 초기화
cd kubernetes-patterns
trunk init
```

### 2. 기본 명령어

```bash
# 단일 파일 검사
trunk check k8s/deployment.yaml

# 기존 이슈 포함 표시
trunk check k8s/deployment.yaml --show-existing

# 여러 파일 동시 검사
trunk check "apps/**/*.yaml"

# 특정 린터만 사용
trunk check --filter=kube-linter apps/

# 자동 수정
trunk check --fix k8s/deployment.yaml
```

## 📂 패턴별 린팅 전략

### 1. Declarative Deployment Pattern

배포 전략(Rolling Update, Blue-Green, Canary)에 집중

#### 필수 체크 항목

```yaml
# .kube-linter-declarative.yaml
checks:
  addAllBuiltIn: true
  
  # 이 패턴에서는 특별히 중요한 체크
  include:
    - minimum-three-replicas        # 고가용성 보장
    - unset-cpu-requirements         # 리소스 관리 필수
    - unset-memory-requirements      # 메모리 제한 필수
    - writable-host-mount           # 호스트 마운트 금지
    - wildcard-in-rules             # RBAC 와일드카드 금지

  # 이 패턴에서는 완화 가능한 체크
  exclude:
    - no-read-only-root-fs          # 일부 배포 전략에서는 쓰기 필요
    - required-annotation-email      # 이메일은 선택사항
    - required-label-owner          # owner 라벨은 선택사항

customChecks:
  # 배포 전략 라벨 필수
  - name: deployment-strategy-label
    description: Deployment must have deployment-strategy label
    remediation: Add 'deployment-strategy' label (rolling/blue-green/canary)
    scope:
      objectKinds:
        - DeploymentLike
    template: required-label
    params:
      key: deployment-strategy
  
  # 롤백을 위한 버전 라벨 필수
  - name: version-label-required
    description: All resources must have version label
    remediation: Add 'version' label for rollback tracking
    scope:
      objectKinds:
        - DeploymentLike
    template: required-label  
    params:
      key: version
```

### 2. Managed Lifecycle Pattern

라이프사이클 후크와 graceful shutdown에 집중

#### 필수 체크 항목

```yaml
# .kube-linter-lifecycle.yaml
checks:
  addAllBuiltIn: true
  
  # 이 패턴에서 특별히 중요한 체크
  include:
    - no-liveness-probe              # Liveness probe 필수
    - no-readiness-probe             # Readiness probe 필수
    - mismatching-selector          # 셀렉터 일치 확인
    - dangling-service              # 댕글링 서비스 방지

  # 이 패턴에서는 완화 가능한 체크
  exclude:
    - minimum-three-replicas        # 테스트 목적으로 1개도 허용
    - unset-cpu-requirements        # CPU는 선택사항
    - drop-net-raw-capability       # 네트워크 디버깅 허용

customChecks:
  # PreStop 후크 필수 (graceful shutdown)
  - name: prestop-hook-configured
    description: PreStop hook recommended for graceful shutdown
    remediation: Add lifecycle.preStop with proper shutdown logic
    scope:
      objectKinds:
        - DeploymentLike
    template: required-annotation
    params:
      key: lifecycle/prestop-configured

  # TerminationGracePeriodSeconds 설정 확인
  - name: termination-grace-period
    description: Pod must have appropriate terminationGracePeriodSeconds
    remediation: Set terminationGracePeriodSeconds (30-60s recommended)
    scope:
      objectKinds:
        - DeploymentLike
    template: required-annotation
    params:
      key: lifecycle/termination-period
```

### 3. Health Probe Pattern

헬스체크 설정에 집중

#### 필수 체크 항목

```yaml
# .kube-linter-health.yaml
checks:
  addAllBuiltIn: true
  
  # 헬스 프로브 관련 엄격한 체크
  include:
    - no-liveness-probe
    - no-readiness-probe
    - liveness-port-not-named
    - readiness-port-not-named

  exclude:
    - run-as-non-root               # 헬스체크 테스트시 root 허용
    - required-label-owner          # 선택사항

customChecks:
  # StartupProbe 권장 (k8s 1.20+)
  - name: startup-probe-recommended
    description: Consider using startupProbe for slow-starting containers
    remediation: Add startupProbe for containers that need time to initialize
    scope:
      objectKinds:
        - DeploymentLike
    template: required-annotation
    params:
      key: health/startup-probe

  # Probe 타이밍 설정 검증
  - name: probe-timing-configuration
    description: Probes should have appropriate timing settings
    remediation: Set initialDelaySeconds, periodSeconds, timeoutSeconds appropriately
    scope:
      objectKinds:
        - DeploymentLike
    template: required-annotation
    params:
      key: health/timing-configured
```

## 🛠️ 실전 문제 해결

### 문제 1: "latest" 태그 사용

**발견된 이슈:**

```
The container "app" is using an invalid container image, "nginx:latest"
```

**해결 방법:**

```yaml
# 변경 전
image: nginx:latest

# 변경 후
image: nginx:1.21  # 구체적인 버전 명시
```

### 문제 2: 리소스 제한 미설정

**발견된 이슈:**

```
container "app" has cpu request 0
container "app" has memory limit 0
```

**해결 방법:**

```yaml
containers:
- name: app
  image: nginx:1.21
  resources:
    requests:
      memory: "64Mi"
      cpu: "250m"
    limits:
      memory: "128Mi"
      cpu: "500m"
```

### 문제 3: 보안 컨텍스트 미설정

**발견된 이슈:**

```
container "app" is not set to runAsNonRoot
container "app" does not have a read-only root file system
```

**해결 방법:**

```yaml
spec:
  securityContext:
    runAsNonRoot: true
    runAsUser: 1000
  containers:
  - name: app
    securityContext:
      readOnlyRootFilesystem: true
      allowPrivilegeEscalation: false
```

### 문제 4: Probe 미설정

**발견된 이슈:**

```
container "app" does not specify a liveness probe
container "app" does not specify a readiness probe
```

**해결 방법:**

```yaml
containers:
- name: app
  livenessProbe:
    httpGet:
      path: /health
      port: 8080
    initialDelaySeconds: 30
    periodSeconds: 10
  readinessProbe:
    httpGet:
      path: /ready
      port: 8080
    initialDelaySeconds: 5
    periodSeconds: 5
```

## 🔧 디렉토리 구조별 설정

```bash
kubernetes-patterns/
├── .trunk/
│   └── trunk.yaml                    # 전역 Trunk 설정
├── foundational/
│   ├── declarative-deployment/
│   │   ├── .kube-linter.yaml        # 기본 설정
│   │   ├── .kube-linter-rolling.yaml    # Rolling Update 전용
│   │   ├── .kube-linter-bluegreen.yaml  # Blue-Green 전용
│   │   ├── .kube-linter-canary.yaml     # Canary 전용
│   │   └── apps/
│   │       ├── rolling-update/
│   │       ├── blue-green/
│   │       └── canary/
│   ├── managed-lifecycle/
│   │   ├── .kube-linter.yaml        # Lifecycle 패턴 전용
│   │   └── k8s/
│   └── health-probe/
│       ├── .kube-linter.yaml        # Health 패턴 전용
│       └── k8s/
```

## 📝 환경별 설정 예시

### 개발 환경용 설정 (.kube-linter-dev.yaml)

```yaml
# 개발시 자주 사용하는 완화 설정
checks:
  addAllBuiltIn: true
  
  exclude:
    - latest-tag                   # 개발시 latest 허용
    - run-as-non-root             # 디버깅을 위해 root 허용
    - no-read-only-root-fs        # 로그 작성 등을 위해 허용
    - minimum-three-replicas      # 리소스 절약
    - required-annotation-email   # 불필요한 메타데이터
    - required-label-owner        # 불필요한 메타데이터
```

### 프로덕션 환경용 설정 (.kube-linter-prod.yaml)

```yaml
# 프로덕션 환경 엄격한 설정
checks:
  addAllBuiltIn: true
  
  # 추가 체크 명시적 포함
  include:
    - latest-tag
    - run-as-non-root
    - no-read-only-root-fs
    - minimum-three-replicas
    - unset-cpu-requirements
    - unset-memory-requirements
    - no-liveness-probe
    - no-readiness-probe
  
  # 최소한의 예외만 허용
  exclude:
    - required-annotation-email  # 조직에 따라 선택
```

## 📊 패턴별 실행 명령

### 1. 개별 패턴 린팅

```bash
# Declarative Deployment 패턴
cd declarative-deployment
trunk check --filter=kube-linter apps/

# Managed Lifecycle 패턴  
cd managed-lifecycle
trunk check --filter=kube-linter k8s/

# Health Probe 패턴
cd health-probe
trunk check --filter=kube-linter k8s/
```

### 2. 특정 배포 전략만 체크

```bash
# Rolling Update만 체크
trunk check apps/rolling-update/

# Blue-Green만 체크
trunk check apps/blue-green/

# Canary만 체크
trunk check apps/canary/
```

## 🔍 디버깅 및 트러블슈팅

### 1. 일반적인 문제 해결

```bash
# 설정 확인
trunk check --print-config

# 상세 로그 출력
trunk check --verbose

# 린터 목록 확인
trunk check list

# 캐시 초기화
trunk cache clean

# 특정 심각도 이상만 표시
trunk check --severity=error
```

### 2. 커스텀 설정이 적용되지 않을 때

```bash
# 현재 디렉토리에서 설정 파일 확인
ls -la .kube-linter.yaml
ls -la .trunk/configs/.kube-linter.yaml

# 심볼릭 링크 생성
mkdir -p .trunk/configs
ln -sf ../../.kube-linter.yaml .trunk/configs/.kube-linter.yaml
```

### 3. kube-linter를 찾을 수 없을 때

```bash
# trunk 도구 재설치
trunk install kube-linter

# 설치 확인
find ~/.cache/trunk -name "kube-linter" -type f
```

## 📚 추가 자료

- [Trunk 공식 문서](https://docs.trunk.io/)
- [KubeLinter 공식 문서](https://docs.kubelinter.io/)
- [Kubernetes 보안 베스트 프랙티스](https://kubernetes.io/docs/concepts/security/)
- [YAML 린팅 가이드](https://yamllint.readthedocs.io/)

## 🤝 기여

설정 개선 사항이나 문제가 있으면 Issue를 생성하거나 PR을 보내주세요.
