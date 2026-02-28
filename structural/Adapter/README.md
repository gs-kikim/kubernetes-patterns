# Adapter Pattern

> Chapter 17 of "Kubernetes Patterns" by Bilgin Ibryam and Roland Huß

## 개요

**Adapter Pattern**은 이기종(heterogeneous) 컨테이너화된 시스템을 일관되고 통합된 인터페이스로 변환하여 외부 시스템이 표준화된 형식으로 접근할 수 있도록 하는 패턴입니다.

### 핵심 개념

```
┌─────────────────────────────────────────────────────────┐
│                         Pod                             │
│  ┌─────────────────┐    ┌─────────────────────────┐    │
│  │                 │    │                         │    │
│  │  Main Container │───▶│   Adapter Container     │───▶│ 외부 시스템
│  │  (Application)  │    │   (Format Transformer)  │    │ (Prometheus,
│  │                 │    │                         │    │  ELK 등)
│  │  - Custom Log   │    │  - 표준 형식 변환       │    │
│  │  - Custom Metric│    │  - HTTP 엔드포인트 제공 │    │
│  └────────┬────────┘    └─────────────────────────┘    │
│           │                        ▲                    │
│           └────────────────────────┘                    │
│              Shared Volume (logs, metrics)              │
└─────────────────────────────────────────────────────────┘
```

## 디렉토리 구조

```
Adapter/
├── README.md                          # 이 파일
├── example1-basic-prometheus/         # 기본 Prometheus Adapter
│   ├── README.md
│   ├── random-generator.py            # 메인 애플리케이션
│   ├── prometheus-adapter.py          # Adapter 컨테이너
│   ├── Dockerfile.app
│   ├── Dockerfile.adapter
│   ├── deployment.yaml
│   └── servicemonitor.yaml
│
├── example2-jmx-exporter/             # JMX → Prometheus 변환
│   ├── README.md
│   ├── SimpleJavaApp.java             # JMX 기반 Java 앱
│   ├── Dockerfile.javaapp
│   ├── jmx-config.yaml                # 변환 규칙
│   └── deployment.yaml
│
├── example3-log-format/               # 로그 형식 통합
│   ├── README.md
│   ├── multi-format-app.py            # 다양한 로그 형식 생성
│   ├── fluent-bit.conf                # Fluent Bit 설정
│   ├── parsers.conf                   # 로그 파서 정의
│   ├── Dockerfile.app
│   └── deployment.yaml
│
├── example4-native-sidecar/           # Native Sidecar (K8s 1.28+)
│   ├── README.md
│   ├── batch-job.py                   # Batch Job 애플리케이션
│   ├── metrics-adapter.py             # Metrics Adapter
│   ├── Dockerfile.job
│   ├── Dockerfile.adapter
│   ├── job-traditional.yaml           # 문제 재현
│   ├── job-native-sidecar.yaml        # 해결책
│   └── deployment-native-sidecar.yaml
│
└── tests/                             # 통합 테스트
    ├── test-all.sh                    # 전체 테스트
    ├── test-example1.sh               # Example 1 테스트
    └── test-example4-comparison.sh    # Traditional vs Native 비교
```

## 예제 목록

### [Example 1: Basic Prometheus Adapter](example1-basic-prometheus/)

**난이도**: ⭐️ 초급
**학습 목표**: Adapter Pattern의 기본 개념 이해

메인 애플리케이션이 커스텀 JSON 형식으로 메트릭을 로그 파일에 기록하면, Adapter가 이를 Prometheus 형식으로 변환하여 노출합니다.

**핵심 기술**:
- emptyDir 볼륨을 통한 데이터 공유
- 로그 파일 파싱 및 변환
- Prometheus Client 라이브러리

**테스트 방법**:
```bash
cd example1-basic-prometheus
./test.sh  # 또는
../tests/test-example1.sh
```

---

### [Example 2: JMX Exporter Adapter](example2-jmx-exporter/)

**난이도**: ⭐️⭐️ 중급
**학습 목표**: 레거시 시스템 통합, 프로토콜 변환

레거시 Java 애플리케이션의 JMX 메트릭을 Prometheus 형식으로 변환합니다. 실무에서 가장 흔한 Adapter 사용 사례입니다.

**핵심 기술**:
- JMX (Java Management Extensions)
- Bitnami JMX Exporter
- ConfigMap을 통한 변환 규칙 관리
- localhost 네트워크 통신

**실무 적용**:
- Spring Boot (Actuator 사용 전)
- Tomcat, JBoss 레거시 애플리케이션
- Kafka, Cassandra 등 JMX 기반 시스템

---

### [Example 3: Log Format Adapter](example3-log-format/)

**난이도**: ⭐️⭐️⭐️ 중급~고급
**학습 목표**: 다양한 로그 형식 통합, Fluent Bit 활용

Apache, Syslog, CSV, 커스텀 형식 등 다양한 로그를 표준 JSON으로 변환하여 중앙 로깅 시스템(ELK, Loki)에 통합합니다.

**핵심 기술**:
- Fluent Bit 로그 프로세서
- 정규표현식 파싱
- 다중 파서 체인
- ConfigMap을 통한 파서 설정

**지원 로그 형식**:
- Apache Common Log Format
- Custom Application Format
- Syslog-like Format
- CSV Format

---

### [Example 4: Native Sidecar Adapter](example4-native-sidecar/)

**난이도**: ⭐️⭐️⭐️⭐️ 고급
**학습 목표**: Kubernetes 1.28+ Native Sidecar, Job과의 통합

**요구 사항**: Kubernetes 1.28+ (1.29+ 권장)

Traditional Sidecar의 문제점(Job이 완료되지 않음)을 Native Sidecar로 해결합니다. Kubernetes의 최신 기능을 활용한 고급 패턴입니다.

**핵심 기술**:
- Native Sidecar (`restartPolicy: Always` in initContainers)
- Startup/Liveness/Readiness Probes
- Job 라이프사이클 관리
- 시작/종료 순서 제어

**비교**:
| 특성 | Traditional Sidecar | Native Sidecar |
|------|---------------------|----------------|
| Job 완료 | ✗ 불가능 | ✓ 가능 |
| 시작 순서 | ✗ 보장 안됨 | ✓ 보장됨 |
| 종료 순서 | ✗ 수동 관리 | ✓ 자동 관리 |
| Probe 지원 | ✗ 제한적 | ✓ 완전 지원 |

**테스트 방법**:
```bash
cd example4-native-sidecar
# Traditional vs Native Sidecar 비교
../tests/test-example4-comparison.sh
```

## 빠른 시작

### 전제 조건

- Kubernetes 클러스터 (Minikube, Kind, EKS 등)
- kubectl 설치
- Docker 설치
- (Example 4) Kubernetes 1.28+ (Native Sidecar 지원)

### 전체 테스트 실행

```bash
# 모든 예제 테스트
./tests/test-all.sh
```

### 개별 예제 테스트

```bash
# Example 1
cd example1-basic-prometheus
kubectl apply -f deployment.yaml

# 확인
kubectl get pods -l app=random-generator
kubectl logs -l app=random-generator -c prometheus-adapter

# 정리
kubectl delete -f deployment.yaml
```

## Adapter vs Sidecar vs Ambassador

| 패턴 | 목적 | 데이터 방향 | 역할 | 대표 예시 |
|------|------|-------------|------|-----------|
| **Sidecar** | 메인 앱 기능 확장 | 양방향 | 보조 기능 제공 | Git sync, Log rotation |
| **Adapter** | 데이터 형식 변환 | 내부 → 외부 | Reverse Proxy | Prometheus Exporter |
| **Ambassador** | 외부 접근 추상화 | 외부 → 내부 | Forward Proxy | Service mesh proxy |

**Adapter Pattern의 특징**:
- Sidecar Pattern의 특수화
- 외부 세계에 통합된 인터페이스 제공
- 메인 애플리케이션은 Adapter를 인식하지 못함
- 관심사 분리를 통한 유지보수성 향상

## 실무 활용 시나리오

### 1. 모니터링 시스템 통합
```
다양한 메트릭 형식 → Adapter → Prometheus
- JMX (Java)
- StatsD (Node.js)
- Custom (Python)
- Windows Perfmon
```

### 2. 로그 중앙화
```
다양한 로그 형식 → Adapter → ELK/Loki
- Apache logs
- Application logs
- System logs
- Structured JSON
```

### 3. 레거시 시스템 현대화
```
Legacy App → Adapter → Cloud Native Platform
- 코드 수정 없이 통합
- 점진적 마이그레이션
- 리스크 최소화
```

### 4. 분산 추적
```
다양한 트레이싱 → Adapter → Jaeger/Zipkin
- OpenTelemetry Collector
- 다중 백엔드 지원
- 형식 변환
```

## Best Practices

### 1. 리소스 관리
```yaml
# Adapter는 메인 앱보다 작은 리소스 할당
resources:
  requests:
    memory: "32Mi"   # 메인 앱의 1/4 ~ 1/2
    cpu: "25m"
```

### 2. 볼륨 마운트
```yaml
# Adapter는 읽기 전용으로 마운트
volumeMounts:
- name: shared-data
  mountPath: /data
  readOnly: true  # 중요!
```

### 3. 헬스체크 (Native Sidecar)
```yaml
startupProbe:   # 초기 시작 확인
  httpGet:
    path: /health
    port: 9889
  failureThreshold: 10

livenessProbe:  # 지속적 상태 확인
  httpGet:
    path: /health
    port: 9889
  periodSeconds: 10
```

### 4. 보안
```yaml
securityContext:
  runAsNonRoot: true
  runAsUser: 1000
  readOnlyRootFilesystem: true
  allowPrivilegeEscalation: false
```

## 문제 해결

### Adapter가 메트릭을 수집하지 못함

**원인**: 볼륨 마운트 경로 불일치

**해결**:
```yaml
# 메인 앱과 Adapter의 마운트 경로 일치 확인
containers:
- name: app
  env:
  - name: LOG_FILE
    value: /var/log/app.log  # 동일한 경로
  volumeMounts:
  - name: logs
    mountPath: /var/log

- name: adapter
  env:
  - name: LOG_FILE
    value: /var/log/app.log  # 동일한 경로
  volumeMounts:
  - name: logs
    mountPath: /var/log
```

### Native Sidecar가 동작하지 않음

**원인**: Kubernetes 버전 또는 Feature Gate

**해결**:
```bash
# 버전 확인 (1.28+ 필요)
kubectl version --short

# Feature Gate 확인 (1.28)
kubectl get --raw /metrics | grep SidecarContainers

# Minikube 사용 시
minikube start \
  --kubernetes-version=v1.29.0 \
  --feature-gates=SidecarContainers=true
```

### Job이 완료되지 않음 (Traditional Sidecar)

**원인**: Sidecar가 계속 실행됨

**해결**: Native Sidecar 사용 (Example 4 참고)

## 참고 자료

### 공식 문서
- [Kubernetes Patterns Book](https://www.oreilly.com/library/view/kubernetes-patterns/9781492050278/)
- [Kubernetes Sidecar Containers](https://kubernetes.io/docs/concepts/workloads/pods/sidecar-containers/)
- [KEP-753: Sidecar Containers](https://github.com/kubernetes/enhancements/tree/master/keps/sig-node/753-sidecar-containers)

### 도구 및 프로젝트
- [Prometheus](https://prometheus.io/)
- [Fluent Bit](https://fluentbit.io/)
- [OpenTelemetry](https://opentelemetry.io/)
- [JMX Exporter](https://github.com/prometheus/jmx_exporter)

### 관련 패턴
- Sidecar Pattern (기본 패턴)
- Ambassador Pattern (외부 접근)
- Init Container Pattern (초기화)

## 버전 히스토리

| 버전 | 날짜 | 변경 사항 |
|------|------|-----------|
| 1.0 | 2024-01 | 초기 버전 (4개 예제) |

## 라이선스

이 예제들은 학습 목적으로 제공됩니다.

## 기여

버그 리포트나 개선 제안은 Issues를 통해 제출해 주세요.

---

**다음 챕터**: [Ambassador Pattern](../Ambassador/) - 외부 서비스 접근 추상화
