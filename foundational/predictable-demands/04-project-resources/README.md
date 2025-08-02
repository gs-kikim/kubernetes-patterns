# Project Resources

이 디렉토리는 Kubernetes의 프로젝트(네임스페이스) 레벨 리소스 관리를 다루는 예제입니다.

## 📋 예제 목록

1. **namespace-setup.yaml** - 네임스페이스별 환경 구성
2. **resource-quotas.yaml** - ResourceQuota 설정
3. **limit-ranges.yaml** - LimitRange 설정
4. **quota-monitoring.yaml** - 리소스 할당량 모니터링

## 🎯 학습 내용

- ResourceQuota로 네임스페이스 리소스 총량 제한
- LimitRange로 개별 오브젝트 리소스 제한
- 네임스페이스별 리소스 격리
- 할당량 모니터링 및 관리

## 🚀 실행 방법

### 1. 네임스페이스 환경 설정

```bash
# 네임스페이스와 기본 설정 생성
kubectl apply -f namespace-setup.yaml

# 네임스페이스 확인
kubectl get namespaces --show-labels
```

### 2. ResourceQuota 적용

```bash
# ResourceQuota 생성
kubectl apply -f resource-quotas.yaml

# 할당량 상태 확인
kubectl describe resourcequota -A
```

### 3. LimitRange 적용

```bash
# LimitRange 생성
kubectl apply -f limit-ranges.yaml

# 제한 범위 확인
kubectl describe limitrange -A
```

### 4. 모니터링

```bash
# 리소스 사용량 모니터링
kubectl apply -f quota-monitoring.yaml

# 로그 확인
kubectl logs -f quota-monitor
```

## 📝 주요 포인트

### ResourceQuota 제한 항목

- **컴퓨트 리소스**: CPU, 메모리 requests/limits
- **스토리지**: PVC 수, 총 스토리지 용량
- **오브젝트 수**: Pod, Service, ConfigMap 등

### LimitRange 적용 범위

- **Container**: 개별 컨테이너 제한
- **Pod**: Pod 전체 제한
- **PersistentVolumeClaim**: 스토리지 크기 제한

### 권장 설정

- 프로덕션: 엄격한 quota와 적절한 limits
- 개발: 유연한 quota, 최소 limits
- 테스트: 제한적인 리소스로 비용 최적화