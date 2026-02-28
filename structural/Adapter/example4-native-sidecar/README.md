# Example 4: Native Sidecar Adapter

## 개요

Kubernetes 1.28+의 Native Sidecar 기능을 활용한 Adapter Pattern 구현입니다.

**핵심 차이점**:
- **Traditional Sidecar**: Job이 완료되어도 Sidecar가 계속 실행 → Pod 종료 안됨
- **Native Sidecar**: Job 완료 시 Sidecar도 자동 종료 → Pod 정상 완료

## Kubernetes 버전 요구사항

| Kubernetes Version | Status | Feature Gate |
|-------------------|--------|--------------|
| 1.28 | Alpha | `SidecarContainers=true` (수동 활성화) |
| 1.29+ | Beta | 기본 활성화 |
| 1.33+ (예정) | GA | 항상 활성화 |

### 버전 확인

```bash
# Kubernetes 버전 확인
kubectl version --short

# Feature gate 확인 (1.28)
kubectl get --raw /metrics | grep kubernetes_feature_enabled | grep SidecarContainers
```

## 아키텍처 비교

### Traditional Sidecar (문제)

```
Job Lifecycle:
1. Init Containers → 순차 실행
2. Main + Sidecar → 동시 시작
3. Main Container → 완료 ✓
4. Sidecar Container → 계속 실행! ✗
5. Pod → 종료되지 않음 (Running 상태 유지)

Result: Job이 절대 Complete 상태가 되지 않음!
```

### Native Sidecar (해결)

```
Job Lifecycle:
1. Native Sidecar (in initContainers) → 시작
   - startupProbe 성공 시 다음 단계로
2. Main Container → 시작 (Sidecar 준비 완료!)
3. Main Container → 완료 ✓
4. Native Sidecar → 자동 종료 ✓
5. Pod → Completed ✓

Result: Job이 정상적으로 Complete!
```

## 배포 방법

### 1. 이미지 빌드

```bash
# Batch job
docker build -t k8spatterns/batch-job:1.0 -f Dockerfile.job .

# Metrics adapter
docker build -t k8spatterns/metrics-adapter:1.0 -f Dockerfile.adapter .
```

### 2. Traditional Sidecar 테스트 (문제 재현)

```bash
# 배포
kubectl apply -f job-traditional.yaml

# Job 상태 확인 (절대 Complete 되지 않음!)
kubectl get jobs batch-job-traditional
kubectl get pods -l app=batch-job,type=traditional

# 로그 확인
kubectl logs -l type=traditional -c batch-processor
# → "Batch Job completed!" 보이지만 Pod는 Running

kubectl logs -l type=traditional -c metrics-adapter
# → Adapter가 계속 실행 중

# 정리
kubectl delete -f job-traditional.yaml
```

예상 결과:
```
NAME                   COMPLETIONS   DURATION   AGE
batch-job-traditional  0/1          2m         2m

NAME                         READY   STATUS    RESTARTS   AGE
batch-job-traditional-xxxxx  1/2     Running   0          2m
                             ^^^
                          문제: 2개 중 1개만 완료!
```

### 3. Native Sidecar 테스트 (해결)

```bash
# 배포
kubectl apply -f job-native-sidecar.yaml

# Job 상태 확인 (정상 Complete!)
kubectl get jobs batch-job-native-sidecar
kubectl get pods -l app=batch-job,type=native-sidecar

# 로그 확인
kubectl logs -l type=native-sidecar -c batch-processor
kubectl logs -l type=native-sidecar -c metrics-adapter

# 메트릭 확인 (Job 실행 중)
kubectl port-forward job/batch-job-native-sidecar 9889:9889 &
curl http://localhost:9889/metrics | grep batch_job

# 정리
kubectl delete -f job-native-sidecar.yaml
```

예상 결과:
```
NAME                        COMPLETIONS   DURATION   AGE
batch-job-native-sidecar   1/1           45s        1m

NAME                              READY   STATUS      RESTARTS   AGE
batch-job-native-sidecar-xxxxx   0/2     Completed   0          1m
                                         ^^^^^^^^^
                                      성공: Job 완료!
```

### 4. Deployment with Native Sidecar

```bash
# 배포
kubectl apply -f deployment-native-sidecar.yaml

# Pod 확인 (시작 순서 확인)
kubectl get pods -l app=native-sidecar-demo -w

# 로그로 시작 순서 확인
kubectl logs -l app=native-sidecar-demo -c metrics-adapter
# → "Adapter ready" 먼저 출력

kubectl logs -l app=native-sidecar-demo -c app
# → Adapter 준비 후 시작

# 메트릭 확인
kubectl port-forward svc/native-sidecar-demo 9889:9889 &
curl http://localhost:9889/metrics | grep batch_job

# 정리
kubectl delete -f deployment-native-sidecar.yaml
```

## Native Sidecar 핵심 설정

### 1. restartPolicy: Always

```yaml
initContainers:
- name: metrics-adapter
  restartPolicy: Always  # 이것이 Native Sidecar를 만듦!
  # ...
```

### 2. Startup Probe

```yaml
startupProbe:
  httpGet:
    path: /metrics
    port: 9889
  initialDelaySeconds: 2
  periodSeconds: 2
  failureThreshold: 10
```

- Native Sidecar가 준비되면 다음 단계(Main Container)로 진행
- 실패하면 Pod 시작 실패

### 3. Liveness/Readiness Probe

```yaml
livenessProbe:
  httpGet:
    path: /metrics
    port: 9889
  periodSeconds: 10

readinessProbe:
  httpGet:
    path: /metrics
    port: 9889
  periodSeconds: 5
```

## Prometheus 메트릭

```bash
curl http://localhost:9889/metrics
```

출력:
```
# HELP batch_job_items_processed Total items processed
# TYPE batch_job_items_processed gauge
batch_job_items_processed 50.0

# HELP batch_job_items_successful Successfully processed items
# TYPE batch_job_items_successful gauge
batch_job_items_successful 45.0

# HELP batch_job_items_failed Failed items
# TYPE batch_job_items_failed gauge
batch_job_items_failed 5.0

# HELP batch_job_success_rate Success rate percentage
# TYPE batch_job_success_rate gauge
batch_job_success_rate 90.0

# HELP batch_job_processing_time_seconds Total processing time
# TYPE batch_job_processing_time_seconds gauge
batch_job_processing_time_seconds 15.234
```

## 실무 적용 시나리오

1. **Batch Jobs with Monitoring**
   - ETL 작업 중 메트릭 수집
   - Job 완료 후 Pod 정상 종료

2. **Database Migrations**
   - 마이그레이션 진행 상황 모니터링
   - 완료 후 자동 정리

3. **Data Processing Pipelines**
   - 처리 중 실시간 메트릭
   - 완료 시 깔끔한 종료

## 학습 포인트

1. **시작 순서 보장**: Adapter가 먼저 준비되어야 Main 시작
2. **종료 순서 보장**: Main 종료 후 Adapter 자동 종료
3. **Job 호환성**: Native Sidecar로 Job 패턴 사용 가능
4. **Probe 활용**: Startup/Liveness/Readiness로 상태 관리

## 문제 해결

### Feature Gate 활성화 (Kubernetes 1.28)

```bash
# kube-apiserver에 추가
--feature-gates=SidecarContainers=true

# kubelet에 추가
--feature-gates=SidecarContainers=true
```

### Minikube 사용 시

```bash
minikube start \
  --kubernetes-version=v1.29.0 \
  --feature-gates=SidecarContainers=true
```

## 정리

```bash
kubectl delete -f job-traditional.yaml
kubectl delete -f job-native-sidecar.yaml
kubectl delete -f deployment-native-sidecar.yaml
```

## 참고 자료

- [KEP-753: Sidecar Containers](https://github.com/kubernetes/enhancements/tree/master/keps/sig-node/753-sidecar-containers)
- [Kubernetes 1.28 Release Notes](https://kubernetes.io/blog/2023/08/15/kubernetes-v1-28-release/)
- [Sidecar Containers Tutorial](https://kubernetes.io/docs/tutorials/configuration/pod-sidecar-containers/)
