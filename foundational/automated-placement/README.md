# Kubernetes Patterns - Chapter 6: Automated Placement

이 디렉토리는 쿠버네티스 패턴 6장 "Automated Placement"의 실습 예제를 포함합니다.

## 📚 개요

Automated Placement 패턴은 쿠버네티스에서 Pod를 노드에 효율적으로 배치하기 위한 다양한 전략을 다룹니다.

### 주요 개념
- **Node Selector**: 간단한 라벨 기반 노드 선택
- **Node Affinity**: 더 유연한 노드 선택 규칙
- **Pod Affinity/Anti-Affinity**: Pod 간 관계 기반 배치
- **Taints and Tolerations**: 노드 격리 및 전용 노드 설정
- **Topology Spread Constraints**: 토폴로지 도메인 간 균등 분산

## 🗂️ 파일 구조

```
automated-placement/
├── node-selector.yml           # Node Selector 예제
├── node-affinity.yml          # Node Affinity 예제  
├── pod-affinity.yml           # Pod Affinity/Anti-Affinity 예제
├── taints-tolerations.yml    # Taints와 Tolerations 예제
├── topology-spread.yml        # Topology Spread Constraints 예제
├── setup-test-env.sh          # 테스트 환경 설정 스크립트
├── test-placement.sh          # 전체 테스트 실행 스크립트
└── README.md                  # 이 문서
```

## 🚀 빠른 시작

### 1. 테스트 환경 설정

```bash
# 테스트 환경 설정 (Minikube 또는 Kind)
./setup-test-env.sh
```

이 스크립트는:
- 3개 노드를 가진 클러스터 생성
- 각 노드에 테스트용 라벨 추가
- Zone, Rack 등의 토폴로지 라벨 설정
- 선택적으로 GPU, Spot 인스턴스 시뮬레이션

### 2. 테스트 실행

```bash
# 모든 배치 패턴 테스트
./test-placement.sh
```

### 3. 개별 예제 실행

```bash
# Node Selector
kubectl apply -f node-selector.yml

# Node Affinity
kubectl apply -f node-affinity.yml

# Pod Affinity/Anti-Affinity
kubectl apply -f pod-affinity.yml

# Taints and Tolerations
kubectl apply -f taints-tolerations.yml

# Topology Spread Constraints
kubectl apply -f topology-spread.yml
```

## 📝 예제 설명

### Node Selector
가장 기본적인 노드 선택 방법으로, 노드 라벨과 정확히 일치하는 조건을 사용합니다.

```yaml
nodeSelector:
  disktype: ssd
  environment: production
```

### Node Affinity
더 복잡한 표현식을 사용한 유연한 노드 선택:
- `requiredDuringSchedulingIgnoredDuringExecution`: 필수 조건
- `preferredDuringSchedulingIgnoredDuringExecution`: 선호 조건

```yaml
affinity:
  nodeAffinity:
    requiredDuringSchedulingIgnoredDuringExecution:
      nodeSelectorTerms:
      - matchExpressions:
        - key: kubernetes.io/os
          operator: In
          values: ["linux"]
```

### Pod Affinity/Anti-Affinity
Pod 간의 관계를 기반으로 배치를 결정:
- **Pod Affinity**: 특정 Pod와 같은 위치에 배치
- **Pod Anti-Affinity**: 특정 Pod와 다른 위치에 배치

```yaml
affinity:
  podAntiAffinity:
    requiredDuringSchedulingIgnoredDuringExecution:
    - labelSelector:
        matchExpressions:
        - key: app
          operator: In
          values: ["redis"]
      topologyKey: kubernetes.io/hostname
```

### Taints and Tolerations
노드를 특정 워크로드 전용으로 예약:

```bash
# 노드에 Taint 추가
kubectl taint nodes node1 gpu=true:NoSchedule

# Pod에 Toleration 추가로 Taint된 노드에 스케줄링 가능
```

### Topology Spread Constraints
Pod를 토폴로지 도메인에 균등하게 분산:

```yaml
topologySpreadConstraints:
- maxSkew: 1
  topologyKey: topology.kubernetes.io/zone
  whenUnsatisfiable: DoNotSchedule
  labelSelector:
    matchLabels:
      app: my-app
```

## 🧪 테스트 시나리오

### 시나리오 1: 고가용성 웹 애플리케이션
- Redis 캐시와 웹 서버를 같은 노드에 배치 (네트워크 레이턴시 최소화)
- 웹 서버 레플리카는 다른 노드에 분산 (고가용성)

### 시나리오 2: 멀티존 데이터베이스
- 데이터베이스를 여러 존에 분산 배치
- 같은 존 내에서도 노드별로 분산

### 시나리오 3: GPU 워크로드
- GPU가 있는 노드에만 ML 워크로드 배치
- Taint와 Toleration으로 GPU 노드 격리

## 🔒 보안 및 린팅 설정

### kube-linter 설정
프로젝트에는 커스텀 `.kube-linter.yaml` 설정이 포함되어 있습니다:

```bash
# kube-linter로 YAML 파일 검증
kube-linter lint *.yml --config .kube-linter.yaml

# 개별 파일 검사
kube-linter lint node-affinity.yml --config .kube-linter.yaml
```

### 추가된 보안 설정

1. **ServiceAccount**: 각 Pod에 전용 ServiceAccount 사용
2. **NetworkPolicy**: Pod 간 네트워크 통신 제어
3. **Security Context**: 비특권 사용자로 실행
4. **Resource Limits**: CPU/Memory 제한 설정
5. **Health Probes**: Liveness/Readiness 프로브 설정
6. **DNS Config**: DNS 해결 최적화
7. **Restart Policy**: 장애 복구 정책
8. **Deployment Strategy**: Rolling Update 전략

### 프로덕션 권장사항

프로덕션 환경에서는 다음 리소스를 먼저 생성하세요:

```bash
# ServiceAccount와 NetworkPolicy 생성
kubectl apply -f common-resources.yml

# 그 다음 워크로드 배포
kubectl apply -f node-affinity.yml
```

## 🔍 모니터링 및 디버깅

### Pod 배치 확인
```bash
# Pod가 어느 노드에 배치되었는지 확인
kubectl get pods -n automated-placement -o wide

# 특정 Pod의 스케줄링 이벤트 확인
kubectl describe pod <pod-name> -n automated-placement

# 팬딩 Pod 확인
kubectl get pods -n automated-placement --field-selector status.phase=Pending
```

### 노드 정보 확인
```bash
# 노드 라벨 확인
kubectl get nodes --show-labels

# 노드 Taint 확인
kubectl describe nodes | grep -A 5 "Taints:"

# 노드별 Pod 수 확인
kubectl get pods -A -o wide | awk '{print $8}' | sort | uniq -c
```

## ⚠️ 주의사항

1. **리소스 요구사항**: 항상 requests/limits를 설정하여 스케줄러가 올바른 결정을 내릴 수 있도록 합니다.

2. **복잡도 관리**: 너무 복잡한 affinity 규칙은 디버깅을 어렵게 만들고 스케줄링 성능에 영향을 줄 수 있습니다.

3. **Topology Key**: `topologyKey`는 노드 라벨이어야 하며, 모든 노드에 해당 라벨이 있어야 합니다.

4. **Hard vs Soft 제약**: 
   - Hard (`required`): 반드시 충족해야 함
   - Soft (`preferred`): 가능하면 충족

5. **기존 Pod 영향**: Affinity 규칙은 이미 실행 중인 Pod에는 영향을 주지 않습니다.

## 🧹 정리

```bash
# 네임스페이스 삭제
kubectl delete namespace automated-placement

# Taint 제거 (설정한 경우)
kubectl taint nodes <node-name> special=true:NoSchedule-

# 클러스터 삭제 (테스트 환경)
# Minikube
minikube delete --profile automated-placement

# Kind
kind delete cluster --name automated-placement
```

## 📚 추가 학습 자료

- [Kubernetes 공식 문서 - Scheduling](https://kubernetes.io/docs/concepts/scheduling-eviction/)
- [Pod Topology Spread Constraints](https://kubernetes.io/docs/concepts/scheduling-eviction/topology-spread-constraints/)
- [Taints and Tolerations](https://kubernetes.io/docs/concepts/scheduling-eviction/taint-and-toleration/)
- [Kubernetes Patterns 책](https://k8spatterns.io/)

## 🤝 기여

이 예제는 [Kubernetes Patterns](https://github.com/k8spatterns/examples) 레포지토리를 참고하여 작성되었습니다.