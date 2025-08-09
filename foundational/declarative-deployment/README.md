# 선언적 배포 패턴 with FluxCD - Minikube 실습 가이드

declarative-deployment 에서는 Kubernetes Patterns 3장의 선언적 배포 패턴을 FluxCD와 함께 Minikube 환경에서 실습할 수 있는 예제를 제공합니다.

## 📋 목차

- [사전 요구사항](#-사전-요구사항)
- [빠른 시작](#-빠른-시작)
- [배포 전략 예제](#-배포-전략-예제)
- [테스트 시나리오](#-테스트-시나리오)
- [문제 해결](#-문제-해결)

## 🔧 사전 요구사항

- **Minikube**: v1.30.0 이상
- **kubectl**: v1.28.0 이상
- **Flux CLI**: v2.0.0 이상 (설치 스크립트에 포함)
- **메모리**: 최소 8GB RAM 권장
- **CPU**: 최소 4 코어 권장

## 🚀 빠른 시작

### 1. Minikube 환경 설정

```bash
# 실행 권한 부여
chmod +x scripts/*.sh

# Minikube 설정 및 시작
./scripts/setup-minikube.sh
```

### 2. FluxCD 설치

```bash
# FluxCD 컴포넌트 설치
./scripts/install-fluxcd.sh

# (선택) Flagger 설치 - 카나리 배포용
./scripts/install-flagger.sh
```

### 3. 배포 전략 테스트

각 배포 전략을 개별적으로 테스트할 수 있습니다:

```bash
# 롤링 업데이트 테스트
./scripts/test-rolling-update.sh

# 블루-그린 배포 테스트
./scripts/test-blue-green.sh

# 카나리 배포 테스트 (Flagger 필요)
./scripts/test-canary.sh
```

## 📦 배포 전략 예제

### 1. 롤링 업데이트 (Rolling Update)

**특징:**
- 점진적으로 파드를 교체
- 다운타임 없음
- 리소스 효율적 (110-125% 사용)

**구조:**
```
apps/rolling-update/
├── deployment.yaml       # 기본 Deployment 정의
├── kustomization.yaml    # Kustomize 설정
└── flux-kustomization.yaml # FluxCD 설정
```

**테스트 방법:**
```bash
# 배포 적용
kubectl apply -f apps/rolling-update/flux-kustomization.yaml

# 버전 업데이트
kubectl -n rolling-demo set image deployment/random-generator \
  random-generator=k8spatterns/random-generator:2.0

# 롤링 업데이트 상태 확인
kubectl -n rolling-demo rollout status deployment/random-generator
```

### 2. 블루-그린 배포 (Blue-Green Deployment)

**특징:**
- 두 개의 완전한 환경 운영
- 즉시 전환 가능
- 빠른 롤백
- 리소스 2배 필요

**구조:**
```
apps/blue-green/
├── deployment-blue.yaml   # Blue 버전
├── deployment-green.yaml  # Green 버전
├── service.yaml          # 서비스 정의
└── kustomization.yaml
```

**테스트 방법:**
```bash
# 초기 배포 (Blue 활성)
kubectl apply -f apps/blue-green/

# Green으로 전환
kubectl -n blue-green-demo patch service random-generator \
  -p '{"spec":{"selector":{"version":"green"}}}'

# Blue로 롤백
kubectl -n blue-green-demo patch service random-generator \
  -p '{"spec":{"selector":{"version":"blue"}}}'
```

### 3. 카나리 배포 (Canary Deployment)

**특징:**
- 트래픽 점진적 이동
- 자동 메트릭 분석
- 자동 롤백
- Flagger 사용

**구조:**
```
apps/canary/
├── deployment.yaml      # 기본 Deployment
├── canary.yaml         # Flagger Canary 리소스
└── kustomization.yaml
```

**테스트 방법:**
```bash
# Flagger 설치 확인
./scripts/install-flagger.sh

# 카나리 리소스 생성
kubectl apply -f apps/canary/

# 카나리 배포 트리거
kubectl -n canary-demo set image deployment/random-generator \
  random-generator=k8spatterns/random-generator:2.0

# 진행 상황 모니터링
kubectl -n canary-demo get canary random-generator --watch
```

## 🧪 테스트 시나리오

### 시나리오 1: 기본 배포 테스트

```bash
# 1. 모든 배포 전략 순차 테스트
./scripts/test-rolling-update.sh
./scripts/test-blue-green.sh
./scripts/test-canary.sh

# 2. 리소스 확인
kubectl get all --all-namespaces | grep -E "rolling|blue-green|canary"
```

### 시나리오 2: 실패 시뮬레이션

```bash
# 잘못된 이미지로 업데이트
kubectl -n rolling-demo set image deployment/random-generator \
  random-generator=k8spatterns/random-generator:invalid

# 롤백
kubectl -n rolling-demo rollout undo deployment/random-generator
```

### 시나리오 3: 부하 테스트

```bash
# 부하 생성기 실행
kubectl run -i --tty load-generator --rm --image=busybox --restart=Never -- \
  /bin/sh -c "while sleep 0.01; do wget -q -O- http://random-generator.rolling-demo/; done"
```

## 🔍 모니터링 및 디버깅

### FluxCD 상태 확인

```bash
# Flux 컴포넌트 상태
flux check

# Kustomization 상태
flux get kustomizations

# 소스 상태
flux get sources git

# 이벤트 확인
kubectl -n flux-system get events --sort-by='.lastTimestamp'
```

### 애플리케이션 모니터링

```bash
# 파드 상태 확인
kubectl get pods -A -l managed-by=fluxcd

# 로그 확인
kubectl -n rolling-demo logs -l app=random-generator --tail=50

# 메트릭 확인 (metrics-server 필요)
kubectl top pods -A
```

## 🛠️ 문제 해결

### 일반적인 문제

#### 1. Minikube 메모리 부족
```bash
minikube stop
minikube config set memory 8192
minikube config set cpus 4
minikube start
```

#### 2. FluxCD 동기화 실패
```bash
# 수동 동기화
flux reconcile source git flux-system

# Kustomization 재조정
flux reconcile kustomization flux-system
```

#### 3. 이미지 풀 오류
```bash
# Minikube 도커 환경 사용
eval $(minikube docker-env)
docker pull k8spatterns/random-generator:1.0
```

### 클린업

```bash
# 개별 네임스페이스 삭제
kubectl delete namespace rolling-demo
kubectl delete namespace blue-green-demo
kubectl delete namespace canary-demo

# FluxCD 제거
flux uninstall --namespace=flux-system

# Minikube 정지
minikube stop

# 완전 초기화
minikube delete
```

## 📚 추가 학습 자료

- [Kubernetes Patterns Book](https://k8spatterns.io/)
- [FluxCD 공식 문서](https://fluxcd.io/docs/)
- [Flagger 문서](https://flagger.app/)
- [예제 저장소](https://github.com/k8spatterns/examples)