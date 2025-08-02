# Resource Profiles

이 디렉토리는 Kubernetes의 리소스 프로파일과 QoS(Quality of Service) 클래스를 다루는 예제입니다.

## 📋 예제 목록

1. **qos-classes.yaml** - QoS 클래스별 Pod 예제 (Guaranteed, Burstable, Best-Effort)
2. **resource-limits.yaml** - CPU와 메모리 리소스 제한 설정
3. **resource-monitoring.yaml** - 리소스 사용량 모니터링 및 테스트

## 🎯 학습 내용

- QoS 클래스의 우선순위 이해
- CPU throttling과 메모리 OOM 동작
- 리소스 requests와 limits의 차이
- 리소스 모니터링 방법

## 🚀 실행 방법

### 1. QoS 클래스 테스트

```bash
# 모든 QoS 클래스 Pod 생성
kubectl apply -f qos-classes.yaml

# QoS 클래스 확인
kubectl get pods -o custom-columns=NAME:.metadata.name,QOS:.status.qosClass

# 리소스 사용량 확인
kubectl top pods
```

### 2. 리소스 제한 테스트

```bash
# 리소스 제한 Pod 생성
kubectl apply -f resource-limits.yaml

# CPU throttling 확인
kubectl exec cpu-test -- cat /sys/fs/cgroup/cpu/cpu.stat | grep throttled

# 메모리 사용량 확인
kubectl exec memory-test -- cat /proc/meminfo | grep MemAvailable
```

### 3. 스트레스 테스트

```bash
# 스트레스 테스트 실행
kubectl apply -f resource-monitoring.yaml

# 실시간 모니터링
watch kubectl top pods

# 이벤트 확인
kubectl get events --sort-by='.lastTimestamp'
```

## 📝 주요 포인트

### QoS 클래스 결정 규칙

1. **Guaranteed**: requests = limits (모든 리소스)
2. **Burstable**: requests < limits 또는 일부만 설정
3. **Best-Effort**: 리소스 설정 없음

### Eviction 우선순위

1. Best-Effort (가장 먼저)
2. Burstable
3. Guaranteed (가장 나중)

### 권장사항

- 프로덕션: Guaranteed 또는 높은 requests의 Burstable
- 개발/테스트: Burstable 또는 Best-Effort
- 배치 작업: Best-Effort