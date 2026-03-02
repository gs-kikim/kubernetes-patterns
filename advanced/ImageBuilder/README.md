# ImageBuilder Pattern - Kubernetes Patterns Chapter 30

이 디렉토리는 Kubernetes Patterns 책의 Chapter 30 "ImageBuilder 패턴"을 구현하고 테스트합니다.

## 개요

ImageBuilder는 Kubernetes 클러스터 내부에서 컨테이너 이미지를 빌드하는 패턴입니다.
외부 CI/CD 시스템 없이도 클러스터 내부에서 Dockerfile을 빌드하고 내장 레지스트리에 push할 수 있습니다.

### 핵심 빌드 엔진

| 빌드 엔진 | 특징 | privileged 필요 | 상태 |
|---|---|---|---|
| **Kaniko** | Docker daemon 없는 사용자 공간 빌드 | 불필요 | Google 아카이브(2025.06), Chainguard 포크 유지 |
| **BuildKit (daemonless)** | 단발성 빌드, buildctl-daemonless.sh | 필요 | 2025-2026 사실상 표준 |
| **BuildKit (daemon)** | 장기 실행 데몬, 빌드 캐시 유지 | 필요 | 프로덕션 권장 |

## 디렉토리 구조

```
ImageBuilder/
├── manifests/
│   ├── build-context-configmap.yml       # Dockerfile + index.html (빌드 컨텍스트)
│   ├── kaniko-build-job.yml              # Kaniko 빌드 Job
│   ├── buildkit-daemonless-job.yml       # BuildKit 단발성 빌드 Job
│   ├── buildkit-daemon-deployment.yml    # BuildKit Daemon (Deployment + Service)
│   ├── buildkit-build-job.yml            # BuildKit Client 빌드 Job
│   └── verify-deployment.yml             # 빌드 이미지 검증 (Deployment + Service)
├── tests/
│   ├── test-yaml-syntax.sh              # YAML 구문 검증
│   ├── test-manifest-structure.sh       # 매니페스트 구조 검증
│   ├── test-imagebuilder-concepts.sh    # 핵심 개념 검증
│   ├── test-cluster-deploy.sh           # 클러스터 배포 테스트
│   └── run-all-tests.sh                 # 전체 테스트 실행
├── README.md
├── BLOG_POST.md
└── TEST_RESULTS.md
```

## 사용 방법

### 1. 사전 준비 (minikube registry addon)

```bash
minikube start
minikube addons enable registry
kubectl wait --for=condition=Ready pod -l kubernetes.io/minikube-addon=registry \
    -n kube-system --timeout=120s
```

### 2. 빌드 컨텍스트 생성

```bash
kubectl create namespace imagebuilder-test
kubectl apply -n imagebuilder-test -f manifests/build-context-configmap.yml
```

### 3. Kaniko로 이미지 빌드

```bash
kubectl apply -n imagebuilder-test -f manifests/kaniko-build-job.yml
kubectl wait --for=condition=Complete job/kaniko-build -n imagebuilder-test --timeout=300s
kubectl logs -n imagebuilder-test -l app=kaniko-build -c kaniko
```

### 4. BuildKit으로 이미지 빌드 (단발성)

```bash
kubectl apply -n imagebuilder-test -f manifests/buildkit-daemonless-job.yml
kubectl wait --for=condition=Complete job/buildkit-daemonless-build -n imagebuilder-test --timeout=300s
```

### 5. BuildKit Daemon + Client로 이미지 빌드

```bash
# Daemon 배포
kubectl apply -n imagebuilder-test -f manifests/buildkit-daemon-deployment.yml
kubectl wait --for=condition=Ready pod -l app=buildkitd -n imagebuilder-test --timeout=180s

# Client로 빌드
kubectl apply -n imagebuilder-test -f manifests/buildkit-build-job.yml
kubectl wait --for=condition=Complete job/buildkit-client-build -n imagebuilder-test --timeout=300s
```

### 6. 빌드된 이미지 검증

```bash
kubectl apply -n imagebuilder-test -f manifests/verify-deployment.yml
kubectl wait --for=condition=Ready pod -l app=imagebuilder-verify -n imagebuilder-test --timeout=180s

# HTTP 응답 확인
VERIFY_POD=$(kubectl get pod -n imagebuilder-test -l app=imagebuilder-verify -o jsonpath='{.items[0].metadata.name}')
kubectl exec -n imagebuilder-test $VERIFY_POD -- wget -q -O- http://localhost
```

### 정리

```bash
kubectl delete namespace imagebuilder-test
```

## 테스트 실행

```bash
# 전체 테스트 (클러스터 테스트는 대화형 프롬프트)
cd tests
bash run-all-tests.sh

# 개별 테스트
bash test-yaml-syntax.sh
bash test-manifest-structure.sh
bash test-imagebuilder-concepts.sh
bash test-cluster-deploy.sh
```

## 테스트 결과

| 테스트 | 항목 수 | 결과 |
|---|---|---|
| Test 1: YAML 구문 검증 | 6 | - |
| Test 2: 매니페스트 구조 검증 | 26 | - |
| Test 3: 블로그 핵심 개념 검증 | 18 | - |
| Test 4: 클러스터 배포 테스트 | 16 | - |
| **합계** | **66** | - |

## 참고 자료

- [Kubernetes Patterns — Chapter 30: ImageBuilder](https://k8spatterns.io)
- [Kaniko (Chainguard fork)](https://github.com/chainguard-dev/kaniko)
- [BuildKit](https://github.com/moby/buildkit)
- [minikube Registry Addon](https://minikube.sigs.k8s.io/docs/handbook/registry/)
