# Network Segmentation Pattern - 실습 가이드

Kubernetes NetworkPolicy를 사용한 네트워크 세그멘테이션 실습입니다.

## 개요

이 실습에서는 다음을 배웁니다:
- Kubernetes NetworkPolicy의 기본 개념
- Deny-All (Zero Trust) 정책 구현
- 레이블 기반 접근 제어
- Ingress/Egress 정책
- 3-Tier 아키텍처의 네트워크 격리
- (선택) Cilium을 통한 L7 정책

## 사전 요구사항

- minikube 설치 ([설치 가이드](https://minikube.sigs.k8s.io/docs/start/))
- kubectl 설치
- (선택) Cilium CLI 설치: `brew install cilium-cli`

## 빠른 시작

### 1. 환경 설정

**Calico CNI 사용 (권장):**
```bash
./00-setup-calico.sh
```

**Cilium CNI 사용 (L7 정책 테스트용):**
```bash
./00-setup-cilium.sh
```

### 2. 테스트 앱 배포

```bash
kubectl apply -f 05-3tier-app-deployment.yaml
```

### 3. 초기 연결 테스트 (정책 적용 전)

```bash
./test-connectivity.sh before
```

모든 연결이 성공해야 합니다.

### 4. Deny-All 정책 적용

```bash
kubectl apply -f 01-deny-all-ingress.yaml
./test-connectivity.sh after-deny
```

모든 연결이 차단되어야 합니다.

### 5. 레이블 기반 허용

```bash
kubectl apply -f 02-allow-labeled-access.yaml
./test-connectivity.sh after-allow
```

`role: random-client` 레이블이 있는 Pod만 접근 가능합니다.

### 6. 정리

```bash
./cleanup.sh
```

## 파일 구조

```
NetworkSegmentation/
├── README.md                    # 이 파일
├── 00-setup-calico.sh           # Calico CNI 환경 설정
├── 00-setup-cilium.sh           # Cilium CNI 환경 설정
├── 01-deny-all-ingress.yaml     # Deny-All 정책
├── 02-allow-labeled-access.yaml # 레이블 기반 접근 허용
├── 03-allow-internal-egress.yaml # 내부 통신만 허용
├── 04-allow-dns.yaml            # DNS 허용
├── 05-3tier-app-deployment.yaml # 3-Tier 앱 배포
├── 06-3tier-networkpolicies.yaml # 3-Tier 완전한 정책
├── test-connectivity.sh         # 연결 테스트 스크립트
├── cleanup.sh                   # 정리 스크립트
└── cilium/                      # Cilium 전용
    ├── 07-cilium-l7-policy.yaml # L7 HTTP 정책
    ├── 08-cilium-dns-egress.yaml # DNS 기반 Egress
    └── test-cilium.sh           # Cilium 테스트
```

## 실습 시나리오

### Phase 1: Deny-All 정책

Zero Trust의 시작점 - 모든 트래픽 차단 후 필요한 것만 허용

```yaml
# 01-deny-all-ingress.yaml
spec:
  podSelector: {}    # 모든 Pod에 적용
  policyTypes:
    - Ingress
  ingress: []        # 빈 배열 = 모든 Ingress 차단
```

### Phase 2: 레이블 기반 접근 제어

특정 레이블을 가진 Pod만 접근 허용

```yaml
# 02-allow-labeled-access.yaml
spec:
  podSelector:
    matchLabels:
      app: random-generator
  ingress:
    - from:
        - podSelector:
            matchLabels:
              role: random-client  # 이 레이블이 있어야 접근 가능
```

### Phase 3: Egress 정책

외부 통신 제어 및 DNS 허용

```bash
kubectl apply -f 03-allow-internal-egress.yaml
kubectl apply -f 04-allow-dns.yaml
./test-connectivity.sh egress
```

### Phase 4: 3-Tier 아키텍처

완전한 네트워크 세그멘테이션

```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│  Frontend   │────▶│   Backend   │────▶│  Database   │
│  (tier:     │     │  (tier:     │     │  (tier:     │
│   frontend) │     │   backend)  │     │   database) │
└─────────────┘     └─────────────┘     └─────────────┘
      │                   │                   │
      ▼                   ▼                   ▼
   Ingress만            Frontend만         Backend만
   허용                 허용               허용
```

```bash
kubectl apply -f 06-3tier-networkpolicies.yaml
./test-connectivity.sh 3tier
```

## Cilium 테스트 (선택)

### L7 HTTP 정책

HTTP 메서드/경로 기반 제어:

```bash
# Cilium 환경 설정
./00-setup-cilium.sh

# L7 정책 적용
kubectl apply -f cilium/07-cilium-l7-policy.yaml

# 테스트
./cilium/test-cilium.sh l7
```

### DNS 기반 Egress

도메인 이름으로 외부 접근 제어:

```bash
kubectl apply -f cilium/08-cilium-dns-egress.yaml
./cilium/test-cilium.sh dns
```

### Hubble 관찰성

```bash
cilium hubble enable --ui
cilium hubble ui  # http://localhost:12000
```

## 테스트 명령어

```bash
# 현재 NetworkPolicy 확인
kubectl get networkpolicies -n production

# 상세 정보
kubectl describe networkpolicy deny-all-ingress -n production

# 수동 연결 테스트
kubectl exec -n production deploy/curl-client -- \
  curl -s --connect-timeout 3 random-generator:8080

# Pod IP 확인
kubectl get pods -n production -o wide
```

## 문제 해결

### Calico Pod가 준비되지 않음
```bash
kubectl get pods -n kube-system -l k8s-app=calico-node
kubectl logs -n kube-system -l k8s-app=calico-node
```

### NetworkPolicy가 적용되지 않음
```bash
# CNI가 NetworkPolicy를 지원하는지 확인
kubectl api-resources | grep networkpolicies

# Policy 이벤트 확인
kubectl get events -n production
```

### DNS가 작동하지 않음
```bash
# DNS 정책 확인
kubectl get networkpolicy allow-dns -n production -o yaml

# DNS 테스트
kubectl exec -n production deploy/curl-client -- nslookup kubernetes.default
```

## Calico vs Cilium 비교

| 기능 | Calico | Cilium |
|------|--------|--------|
| NetworkPolicy | ✅ | ✅ |
| L7 정책 | ❌ | ✅ |
| DNS Egress | ❌ | ✅ |
| 관찰성 | 제한적 | Hubble |
| 설치 복잡도 | 낮음 | 중간 |

## 참고 자료

- [Kubernetes Network Policies](https://kubernetes.io/docs/concepts/services-networking/network-policies/)
- [Calico Documentation](https://docs.tigera.io/calico/latest/)
- [Cilium Documentation](https://docs.cilium.io/)
- [k8spatterns Examples](https://github.com/k8spatterns/examples/tree/main/security/NetworkSegmentation)
