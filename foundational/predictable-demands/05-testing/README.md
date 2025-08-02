# Testing Scripts

이 디렉토리는 Predictable Demands 패턴을 테스트하고 검증하는 스크립트들을 포함합니다.

## 📋 테스트 스크립트 목록

1. **test-dependencies.sh** - 런타임 의존성 테스트
2. **test-resource-limits.sh** - 리소스 제한 및 QoS 테스트
3. **test-priority-preemption.sh** - Pod 우선순위와 선점 테스트
4. **test-quotas.sh** - ResourceQuota 및 LimitRange 테스트
5. **cleanup.sh** - 테스트 환경 정리

## 🚀 실행 방법

### 전체 테스트 실행

```bash
# 모든 테스트 실행
./run-all-tests.sh

# 특정 테스트만 실행
./test-dependencies.sh
```

### 개별 테스트 실행

```bash
# 의존성 테스트
chmod +x test-dependencies.sh
./test-dependencies.sh

# 리소스 제한 테스트
chmod +x test-resource-limits.sh
./test-resource-limits.sh
```

### 테스트 정리

```bash
# 모든 테스트 리소스 정리
./cleanup.sh
```

## 📝 테스트 시나리오

### 1. 의존성 테스트
- PVC 바인딩 실패 시나리오
- ConfigMap 실시간 업데이트
- Secret 마운트 검증

### 2. 리소스 제한 테스트
- CPU throttling 검증
- 메모리 OOM 시나리오
- QoS 클래스별 eviction

### 3. 우선순위 테스트
- 선점 동작 확인
- PodDisruptionBudget 영향
- 우선순위별 스케줄링

### 4. 할당량 테스트
- ResourceQuota 한계 도달
- LimitRange 자동 적용
- 네임스페이스 격리 검증

## ⚠️ 주의사항

- Minikube에 충분한 리소스 할당 필요 (최소 4GB RAM, 2 CPUs)
- metrics-server 애드온 활성화 필수
- 일부 테스트는 노드에 부하 발생
- 실제 프로덕션 환경에서는 실행 금지

## 🔧 Minikube 환경 준비

```bash
# Minikube 리소스 확인
minikube config view

# 필요시 리소스 증가
minikube stop
minikube config set memory 4096
minikube config set cpus 2
minikube start

# 테스트 전 상태 확인
kubectl top nodes
```