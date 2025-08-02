# Runtime Dependencies

이 디렉토리는 Kubernetes에서 런타임 의존성을 관리하는 예제를 포함합니다.

## 📋 예제 목록

1. **storage-dependencies.yaml** - 스토리지 의존성 (PV, PVC, emptyDir)
2. **config-dependencies.yaml** - ConfigMap과 Secret 의존성
3. **network-dependencies.yaml** - 네트워크 의존성 예제

## 🎯 학습 내용

- Volume 타입별 생명주기 이해
- ConfigMap과 Secret 활용 방법
- 환경변수 vs 볼륨 마운트 비교

## 🚀 실행 방법

### 1. 스토리지 의존성 테스트

```bash
# PV와 PVC 생성
kubectl apply -f storage-dependencies.yaml

# Pod 상태 확인
kubectl get pods -w

# 볼륨 마운트 확인
kubectl exec storage-example -- ls -la /data
```

### 2. 구성 의존성 테스트

```bash
# ConfigMap과 Secret 생성
kubectl apply -f config-dependencies.yaml

# 환경변수 확인
kubectl exec config-example -- env | grep DB_

# 마운트된 설정 파일 확인
kubectl exec config-example -- cat /etc/config/app.properties
```

### 3. 네트워크 의존성 테스트

```bash
# Service와 Pod 생성
kubectl apply -f network-dependencies.yaml

# Service 접근 테스트
kubectl port-forward service/web-service 8080:80
```

## 📝 주요 포인트

- **emptyDir**: Pod 삭제 시 데이터 손실
- **PVC**: 영구 데이터 저장에 적합
- **ConfigMap**: 설정 데이터의 중앙 관리
- **Secret**: 민감한 데이터 보호