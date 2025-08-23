# Kubernetes Managed Lifecycle Pattern 실습

이 프로젝트는 Kubernetes의 Managed Lifecycle 패턴을 실습하고 테스트하기 위한 종합적인 예제입니다.

## 📚 개요

Kubernetes에서 관리되는 컨테이너의 수명주기는 단순히 시작과 종료만이 아닙니다. 애플리케이션이 클라우드 네이티브 환경에서 안정적으로 동작하려면 플랫폼이 발생시키는 다양한 수명주기 이벤트에 적절히 반응해야 합니다.

### 핵심 개념

- **SIGTERM/SIGKILL 시그널 처리**
- **PostStart/PreStop Hooks**
- **Graceful Shutdown**
- **Health Probes와의 통합**
- **Init Containers와의 조합**

## 🏗️ 프로젝트 구조

```
managed-lifecycle/
├── app/                        # Go 애플리케이션 예제
│   ├── main.go                # Graceful shutdown 구현
│   ├── Dockerfile             # 컨테이너 이미지 빌드
│   └── go.mod                 # Go 모듈 설정
├── k8s/                        # Kubernetes 매니페스트
│   ├── 01-poststart-hook.yaml    # PostStart Hook 예제
│   ├── 02-prestop-hook.yaml      # PreStop Hook 예제
│   ├── 03-graceful-shutdown.yaml # Graceful Shutdown 예제
│   └── 04-complete-lifecycle.yaml # 통합 수명주기 예제
├── scripts/                    # 테스트 스크립트
│   ├── test-poststart.sh      # PostStart 테스트
│   ├── test-prestop.sh        # PreStop 테스트
│   ├── test-graceful-shutdown.sh # Graceful Shutdown 테스트
│   ├── test-complete-lifecycle.sh # 통합 테스트
│   └── run-all-tests.sh       # 전체 테스트 실행
└── README.md                   # 이 문서
```

## 🚀 빠른 시작

### 사전 요구사항

- Kubernetes 클러스터 (minikube, kind, 또는 실제 클러스터)
- kubectl CLI
- Docker (애플리케이션 빌드용)
- Go 1.21+ (선택사항, 로컬 개발용)

### 설치 및 실행

1. **저장소 클론**
```bash
git clone <repository-url>
cd managed-lifecycle
```

2. **애플리케이션 이미지 빌드**
```bash
cd app
docker build -t lifecycle-demo:latest .
cd ..
```

3. **전체 테스트 실행**
```bash
cd scripts
./run-all-tests.sh
```

## 📖 상세 테스트 가이드

### 1. PostStart Hook 테스트

PostStart Hook은 컨테이너가 생성된 직후 실행되는 훅입니다.

```bash
# PostStart Hook 테스트 실행
./scripts/test-poststart.sh
```

**테스트 내용:**
- PostStart와 메인 컨테이너의 비동기 실행 확인
- PostStart 완료 전 컨테이너 상태 확인
- PostStart 실패 시 컨테이너 재시작 동작

**주요 학습 포인트:**
- PostStart는 ENTRYPOINT와 **비동기적으로** 실행됨
- PostStart가 실패하면 컨테이너가 재시작됨
- 초기화 작업에 적합 (캐시 워밍업, 서비스 등록 등)

### 2. PreStop Hook 테스트

PreStop Hook은 컨테이너 종료 전에 실행되는 블로킹 호출입니다.

```bash
# PreStop Hook 테스트 실행
./scripts/test-prestop.sh
```

**테스트 내용:**
- PreStop → SIGTERM 실행 순서 확인
- terminationGracePeriodSeconds와의 상호작용
- PreStop 실행 시간이 grace period를 초과하는 경우

**주요 학습 포인트:**
- PreStop은 SIGTERM **이전에** 실행됨
- PreStop은 동기적 (블로킹) 실행
- 정리 작업에 적합 (연결 해제, 로그 플러시 등)

### 3. Graceful Shutdown 테스트

실제 애플리케이션의 우아한 종료 구현을 테스트합니다.

```bash
# Go 애플리케이션 빌드 및 테스트
./scripts/test-graceful-shutdown.sh
```

**테스트 내용:**
- SIGTERM 시그널 처리
- 활성 연결 드레이닝
- Rolling Update 중 무중단 처리
- 복잡한 수명주기 시나리오

**주요 학습 포인트:**
- 진행 중인 요청 완료 대기
- 새로운 요청 거부
- 상태 저장 및 리소스 정리

### 4. 완전한 수명주기 통합 테스트

모든 수명주기 구성요소를 통합한 테스트입니다.

```bash
# 통합 테스트 실행
./scripts/test-complete-lifecycle.sh
```

**테스트 내용:**
- Init Container → PostStart → Running → PreStop → SIGTERM 전체 플로우
- Health Probes와의 통합
- Job 리소스의 수명주기
- 복잡한 시나리오 처리

## 🔍 주요 패턴 및 베스트 프랙티스

### SIGTERM 처리 패턴

```go
// Go 예제
sigterm := make(chan os.Signal, 1)
signal.Notify(sigterm, syscall.SIGTERM)

<-sigterm
// Graceful shutdown 로직
ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
defer cancel()
gracefulShutdown(ctx)
```

### PostStart Hook 패턴

```yaml
lifecycle:
  postStart:
    exec:
      command:
      - /bin/sh
      - -c
      - |
        # 초기화 작업
        # 주의: ENTRYPOINT와 비동기 실행
```

### PreStop Hook 패턴

```yaml
lifecycle:
  preStop:
    exec:
      command:
      - /bin/sh
      - -c
      - |
        # 정리 작업
        # SIGTERM 전에 실행됨
```

### Health Probes와 통합

```yaml
readinessProbe:
  httpGet:
    path: /ready
    port: 8080
  # PreStop에서 readiness를 먼저 비활성화

livenessProbe:
  httpGet:
    path: /health
    port: 8080
  # 애플리케이션 건강 상태 확인
```

## 🧪 테스트 시나리오

### 시나리오 1: 무중단 배포

1. 부하 생성 중 Rolling Update 실행
2. PreStop에서 새 트래픽 차단
3. 진행 중인 요청 완료 대기
4. SIGTERM으로 깨끗한 종료

### 시나리오 2: 장애 복구

1. PostStart 실패 시 재시작
2. Liveness Probe 실패 시 재시작
3. SIGKILL까지의 grace period 활용

### 시나리오 3: 복잡한 초기화

1. Init Container로 환경 준비
2. PostStart로 캐시 워밍업
3. Readiness Probe로 트래픽 수신 제어

## 📊 모니터링 및 디버깅

### 유용한 명령어

```bash
# Pod 수명주기 이벤트 확인
kubectl describe pod <pod-name>

# 실시간 로그 모니터링
kubectl logs -f <pod-name>

# Pod 상태 변화 관찰
watch kubectl get pods

# 이벤트 스트림 모니터링
kubectl get events --watch

# 컨테이너 상태 상세 확인
kubectl get pod <pod-name> -o yaml | grep -A 10 containerStatuses
```

### 트러블슈팅

**문제: PostStart가 완료되지 않음**
- 원인: PostStart 스크립트 오류 또는 무한 대기
- 해결: PostStart 로직 검토, 타임아웃 추가

**문제: PreStop이 실행되지 않음**
- 원인: 즉시 SIGKILL 발생
- 해결: terminationGracePeriodSeconds 증가

**문제: Graceful Shutdown이 작동하지 않음**
- 원인: SIGTERM 핸들러 미구현
- 해결: 애플리케이션에 시그널 핸들러 추가

## 🎯 실습 과제

1. **PostStart 최적화**
   - 캐시 워밍업 구현
   - 외부 서비스 등록 로직 추가

2. **PreStop 고도화**
   - 메트릭 수집 및 전송
   - 상태 백업 구현

3. **Zero-downtime 배포**
   - 실제 웹 애플리케이션 적용
   - 부하 테스트 중 배포

4. **복잡한 수명주기**
   - StatefulSet 적용
   - 순차적 시작/종료 구현

## 📚 참고 자료

- [Kubernetes 공식 문서 - Container Lifecycle Hooks](https://kubernetes.io/docs/concepts/containers/container-lifecycle-hooks/)
- [Kubernetes Patterns 책](https://k8spatterns.io/)
- [CNCF 베스트 프랙티스](https://www.cncf.io/blog/)

## 🤝 기여하기

이 프로젝트는 학습 목적으로 만들어졌습니다. 개선 사항이나 버그를 발견하시면 이슈를 생성하거나 PR을 보내주세요.
