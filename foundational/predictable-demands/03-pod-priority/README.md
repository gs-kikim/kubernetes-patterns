# Pod Priority

이 디렉토리는 Kubernetes의 Pod 우선순위와 선점(Preemption) 메커니즘을 다루는 예제입니다.

## 📋 예제 목록

1. **priority-classes.yaml** - PriorityClass 정의
2. **priority-pods.yaml** - 우선순위별 Pod 예제
3. **preemption-test.yaml** - 선점 시나리오 테스트

## 🎯 학습 내용

- PriorityClass 생성 및 사용
- Pod 우선순위 기반 스케줄링
- 선점(Preemption) 동작 원리
- 시스템 Pod 보호 전략

## 🚀 실행 방법

### 1. PriorityClass 생성

```bash
# PriorityClass 생성
kubectl apply -f priority-classes.yaml

# PriorityClass 확인
kubectl get priorityclasses
```

### 2. 우선순위 Pod 배포

```bash
# 다양한 우선순위의 Pod 배포
kubectl apply -f priority-pods.yaml

# Pod 우선순위 확인
kubectl get pods -o custom-columns=NAME:.metadata.name,PRIORITY:.spec.priority,PRIORITY_CLASS:.spec.priorityClassName
```

### 3. 선점 테스트

```bash
# 선점 시나리오 실행
kubectl apply -f preemption-test.yaml

# 선점 이벤트 모니터링
kubectl get events --sort-by='.lastTimestamp' | grep -i preempt
```

## 📝 주요 포인트

### 우선순위 값 범위

- **시스템 클러스터 필수**: 2000000000
- **시스템 노드 필수**: 2000001000
- **사용자 정의**: 0 ~ 1000000000

### 선점 동작

1. 높은 우선순위 Pod이 스케줄링 불가능할 때
2. 낮은 우선순위 Pod 제거 후 스케줄링
3. PodDisruptionBudget 고려

### 모범 사례

- 프로덕션: 1000 이상
- 개발/테스트: 100 ~ 500
- 배치 작업: 0 ~ 100
- 기본값 설정 시 globalDefault 사용