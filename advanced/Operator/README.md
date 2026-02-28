# Operator 패턴 (Kubernetes Patterns - Chapter 28)

## 개요

Operator 패턴은 Controller 패턴을 확장하여 **Custom Resource Definition(CRD)** 를 도입합니다.
Controller가 기존 Kubernetes 리소스(ConfigMap, Pod 등)만 감시하는 반면,
Operator는 새로운 리소스 타입을 정의하고 이를 통해 도메인 특화 운영 지식을 코드화합니다.

## Controller vs Operator

| 구분 | Controller | Operator |
|------|-----------|----------|
| API 확장 | 기존 리소스만 사용 | CRD로 새 리소스 정의 |
| 설정 방식 | Annotation 기반 | CR(Custom Resource) 인스턴스 |
| 도메인 지식 | 범용적 | 도메인 특화 |
| Reconciliation | 있음 | 있음 (CRD 기반) |

## ConfigWatcher Operator 예제

이 예제는 `ConfigWatcher`라는 CRD를 정의하여 ConfigMap 변경 시 관련 Pod를 자동으로 재시작합니다.

### CRD 정의

```yaml
apiVersion: k8spatterns.com/v1
kind: ConfigWatcher
spec:
  configMap: webapp-config      # 감시할 ConfigMap 이름
  podSelector:                  # 재시작할 Pod 선택자
    matchLabels:
      app: webapp
```

### Reconciliation Loop

1. **Observe**: ConfigMap 변경 이벤트 감지 (Kubernetes Watch API)
2. **Analyze**: ConfigWatcher CRD를 조회하여 해당 ConfigMap을 참조하는 CR 탐색
3. **Act**: CR의 `podSelector`에 매칭되는 Pod 삭제 → Deployment가 자동 재생성

### 아키텍처

```
┌─────────────────────────────────────────┐
│         ConfigWatcher Operator           │
│  ┌─────────────┐  ┌──────────────────┐  │
│  │ kubeapi-proxy│  │  config-watcher  │  │
│  │  (sidecar)  │  │  (shell script)  │  │
│  └─────────────┘  └──────────────────┘  │
└─────────────┬───────────────────────────┘
              │ Watch ConfigMaps
              │ Query ConfigWatcher CRDs
              │ Delete matching Pods
              ▼
┌──────────────────────┐
│   Kubernetes API     │
└──────────────────────┘
```

## 사용법

```bash
# 1. CRD 등록
kubectl apply -f manifests/config-watcher-crd.yml

# 2. Operator 배포
kubectl apply -f manifests/config-watcher-operator.yml

# 3. Web App 배포
kubectl apply -f manifests/web-app.yml

# 4. ConfigWatcher CR 생성
kubectl apply -f manifests/config-watcher-sample.yml

# 5. ConfigMap 수정 → Pod 자동 재시작 확인
kubectl patch configmap webapp-config --type merge -p '{"data":{"message":"Updated!"}}'
kubectl get pods -w
```

## 테스트

```bash
# 전체 테스트 실행
bash tests/run-all-tests.sh
```

## 참고

- [k8spatterns/examples - Operator](https://github.com/k8spatterns/examples/tree/main/advanced/Operator)
- [Kubernetes Operator Pattern](https://kubernetes.io/docs/concepts/extend-kubernetes/operator/)
