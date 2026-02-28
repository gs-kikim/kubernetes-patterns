# Example 1: Basic Prometheus Adapter

## 개요

이 예제는 Adapter Pattern의 가장 기본적인 사용 사례를 보여줍니다:
- **메인 앱**: 커스텀 JSON 형식으로 메트릭을 로그 파일에 기록
- **Adapter**: 로그 파일을 읽어 Prometheus 형식으로 변환하여 노출

## 아키텍처

```
┌─────────────────────────────────────────────────────────┐
│                         Pod                             │
│  ┌─────────────────┐    ┌─────────────────────────┐    │
│  │ Random          │    │ Prometheus              │    │
│  │ Generator       │───▶│ Adapter                 │───▶│ Prometheus
│  │                 │    │                         │    │
│  │ /var/log/       │    │ :9889/metrics           │    │
│  │ random.log      │    │                         │    │
│  └────────┬────────┘    └─────────────────────────┘    │
│           │                        ▲                    │
│           └────────────────────────┘                    │
│              emptyDir Volume                            │
└─────────────────────────────────────────────────────────┘
```

## 배포 방법

### 1. 이미지 빌드 (로컬 테스트)

```bash
# Main application
docker build -t k8spatterns/random-generator:1.0 -f Dockerfile.app .

# Adapter
docker build -t k8spatterns/prometheus-adapter:1.0 -f Dockerfile.adapter .
```

### 2. Kubernetes 배포

```bash
# 배포
kubectl apply -f deployment.yaml

# 상태 확인
kubectl get pods -l app=random-generator
kubectl logs -l app=random-generator -c random-generator
kubectl logs -l app=random-generator -c prometheus-adapter
```

### 3. 테스트

```bash
# Port forward
kubectl port-forward svc/random-generator 8080:80 &
kubectl port-forward svc/random-generator 9889:9889 &

# Generate random numbers
for i in {1..10}; do
  curl http://localhost:8080/random
  sleep 1
done

# Check Prometheus metrics
curl http://localhost:9889/metrics | grep random_
```

예상 출력:
```
# HELP random_generation_duration_seconds Time spent generating random numbers
# TYPE random_generation_duration_seconds histogram
random_generation_duration_seconds_bucket{le="0.01"} 0.0
random_generation_duration_seconds_bucket{le="0.025"} 2.0
random_generation_duration_seconds_bucket{le="0.05"} 5.0
...
# HELP random_generation_total Total number of random number generations
# TYPE random_generation_total counter
random_generation_total 10.0
# HELP random_last_generated_value The last generated random value
# TYPE random_last_generated_value gauge
random_last_generated_value 742.0
```

## ServiceMonitor 설정 (Prometheus Operator)

```bash
# Prometheus Operator가 설치된 경우
kubectl apply -f servicemonitor.yaml

# Prometheus UI에서 확인
# Targets 페이지에서 random-generator 확인
```

## 학습 포인트

1. **관심사 분리**: 메인 앱은 Prometheus를 전혀 알지 못함
2. **형식 변환**: JSON → Prometheus OpenMetrics
3. **공유 볼륨**: emptyDir을 통한 데이터 공유
4. **읽기 전용**: Adapter는 readOnly로 마운트

## 정리

```bash
kubectl delete -f deployment.yaml
kubectl delete -f servicemonitor.yaml
```
