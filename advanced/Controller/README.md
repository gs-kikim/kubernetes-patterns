# Controller Pattern - Kubernetes Patterns Chapter 27

이 디렉토리는 Kubernetes Patterns 책의 Chapter 27 "Controller 패턴"을 구현하고 테스트합니다.

## 개요

Controller는 Kubernetes 리소스의 원하는 상태(desired state)와 실제 상태(actual state)를 모니터링하고, 현재 상태를 원하는 상태에 맞추도록 조정하는 능동적 조정 프로세스입니다.

### 핵심 개념

- **Observe-Analyze-Act 사이클**: 이벤트 감시 → 차이점 분석 → 조정 작업 수행
- **Ambassador 패턴**: kubeapi-proxy 사이드카로 localhost를 통해 API Server 접근
- **Singleton Service 패턴**: replicas=1로 동시성 문제 방지
- **Downward API**: WATCH_NAMESPACE 환경변수로 현재 네임스페이스 주입

## 디렉토리 구조

```
Controller/
├── manifests/
│   ├── config-watcher-controller.sh    # Controller Shell Script
│   ├── config-watcher-controller.yml   # Controller Deployment 매니페스트
│   └── web-app.yml                     # 테스트용 Web App 매니페스트
├── tests/
│   ├── test-yaml-syntax.sh             # YAML 구문 검증
│   ├── test-controller-script.sh       # Controller 스크립트 로직 검증
│   ├── test-manifest-structure.sh      # 매니페스트 구조 검증
│   ├── test-blog-concepts.sh           # 블로그 핵심 개념 검증
│   ├── test-cluster-deploy.sh          # 클러스터 배포 테스트
│   └── run-all-tests.sh                # 전체 테스트 실행
└── README.md
```

## 동작 방식

1. **ConfigMap 감시**: Controller는 Kubernetes API의 `watch=true` 파라미터를 사용하여 ConfigMap 변경 이벤트를 실시간으로 수신합니다.

2. **Annotation 확인**: `k8spatterns.com/podDeleteSelector` Annotation이 있는 ConfigMap이 수정되면 해당 값을 Label Selector로 사용합니다.

3. **Pod 재시작**: 해당 Label Selector에 매칭되는 Pod를 삭제하여 재시작을 유도합니다.

## 사용 방법

### 1. 매니페스트 배포

```bash
# Controller 배포
kubectl apply -f manifests/config-watcher-controller.yml

# Web App 배포
kubectl apply -f manifests/web-app.yml
```

### 2. ConfigMap 수정하여 Pod 재시작 테스트

```bash
# ConfigMap 수정
kubectl patch configmap webapp-config --type merge \
  -p '{"data":{"message":"Updated message"}}'

# Pod 재시작 확인
kubectl get pods -l app=webapp -w
```

### 3. Controller 로그 확인

```bash
kubectl logs -l app=config-watcher-controller -c config-watcher -f
```

## 테스트 실행

```bash
cd tests

# 개별 테스트 실행
./test-yaml-syntax.sh          # YAML 구문 검증
./test-controller-script.sh    # Controller 스크립트 검증
./test-manifest-structure.sh   # 매니페스트 구조 검증
./test-blog-concepts.sh        # 핵심 개념 검증
./test-cluster-deploy.sh       # 클러스터 배포 테스트

# 전체 테스트 실행
./run-all-tests.sh
```

## 참고 자료

- [Kubernetes Patterns - Chapter 27](https://github.com/k8spatterns/examples/tree/main/advanced/Controller)
- [controller-runtime](https://github.com/kubernetes-sigs/controller-runtime)
- [Operator SDK](https://sdk.operatorframework.io/)
