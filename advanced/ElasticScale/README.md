# Elastic Scale Pattern - Kubernetes Patterns Chapter 29

이 디렉토리는 Kubernetes Patterns 책의 Chapter 29 "Elastic Scale 패턴"을 구현하고 테스트합니다.

## 개요

Elastic Scale은 워크로드 부하 변화에 따라 Pod 수(HPA), Pod 리소스(VPA), 클러스터 노드 수(CA/Karpenter)를 자동으로 조정하는 패턴입니다.

### 핵심 개념

- **HPA (Horizontal Pod Autoscaler)**: CPU/Memory 메트릭 기반 레플리카 수 자동 조정
- **HPA Behavior**: 비대칭 스케일링 — 빠른 확장 + 보수적 축소 (Flapping 방지)
- **VPA (Vertical Pod Autoscaler)**: Pod 리소스 requests/limits 추천 및 자동 조정
- **Scale-to-Zero**: Knative(HTTP), KEDA(이벤트) 기반 서버리스 스케일링

## 디렉토리 구조

```
ElasticScale/
├── manifests/
│   ├── deployment.yml          # random-generator Deployment + Service
│   ├── hpa.yml                 # HPA 기본 설정 (CPU 50%, 1~5 레플리카)
│   ├── hpa-with-behavior.yml   # HPA + behavior 정책 (비대칭 스케일링)
│   ├── vpa.yml                 # VPA Off 모드 (추천만 제공)
│   └── stress-app.yml          # HPA 실습용 올인원 매니페스트
├── tests/
│   ├── test-yaml-syntax.sh         # YAML 구문 검증
│   ├── test-manifest-structure.sh  # 매니페스트 구조 검증
│   ├── test-blog-concepts.sh       # 블로그 핵심 개념 검증
│   ├── test-cluster-deploy.sh      # 클러스터 배포 테스트 (minikube)
│   └── run-all-tests.sh            # 전체 테스트 실행
├── BLOG_POST.md
├── TEST_RESULTS.md
└── README.md
```

## 사용 방법

### 1. random-generator 배포 (HPA 기본)

```bash
kubectl apply -f manifests/deployment.yml
kubectl apply -f manifests/hpa.yml
```

### 2. HPA behavior 정책 적용

```bash
kubectl apply -f manifests/hpa-with-behavior.yml
```

### 3. VPA 추천 관찰 (VPA 설치 필요)

```bash
kubectl apply -f manifests/vpa.yml
kubectl describe vpa random-generator
```

### 4. HPA 부하 테스트 (올인원)

```bash
# Metrics Server 활성화
minikube addons enable metrics-server

# stress-app 배포 (Deployment + Service + HPA)
kubectl apply -f manifests/stress-app.yml

# 부하 생성
kubectl run load-generator --image=busybox:1.36 --restart=Never -- \
  /bin/sh -c "while true; do wget -q -O- http://stress-app; done"

# HPA 관찰
kubectl get hpa stress-app --watch

# 부하 제거
kubectl delete pod load-generator
```

## 테스트 실행

```bash
cd tests

# 개별 테스트 실행
./test-yaml-syntax.sh          # YAML 구문 검증
./test-manifest-structure.sh   # 매니페스트 구조 검증
./test-blog-concepts.sh        # 핵심 개념 검증
./test-cluster-deploy.sh       # 클러스터 배포 테스트

# 전체 테스트 실행
./run-all-tests.sh
```

## 테스트 결과 (2026-02-21)

| 테스트 | 통과/전체 |
|--------|-----------|
| YAML 구문 검증 | 5/5 |
| 매니페스트 구조 검증 | 22/22 |
| 블로그 핵심 개념 검증 | 18/18 |
| 클러스터 배포 테스트 | 11/11 |
| **전체** | **56/56** |

## 참고 자료

- [k8spatterns/examples - ElasticScale](https://github.com/k8spatterns/examples/tree/main/advanced/ElasticScale)
- [Kubernetes HPA Documentation](https://kubernetes.io/docs/tasks/run-application/horizontal-pod-autoscale/)
- [Vertical Pod Autoscaler](https://github.com/kubernetes/autoscaler/tree/master/vertical-pod-autoscaler)
