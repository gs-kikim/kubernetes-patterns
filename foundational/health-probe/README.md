# Kubernetes Health Probe Pattern - 테스트 코드

## 📚 개요

이 프로젝트는 "Kubernetes Patterns" 책의 4장 정상상태 점검(Health Probe) 패턴에 대한 실습 테스트 코드입니다. Kubernetes의 세 가지 주요 프로브(Liveness, Readiness, Startup)를 실제로 테스트하고 이해할 수 있도록 구성되었습니다.

## 🏗️ 프로젝트 구조

```
health-probe/
├── manifests/                    # Kubernetes 매니페스트 파일
│   ├── 01-liveness-http.yaml    # HTTP Liveness Probe 테스트
│   ├── 02-liveness-tcp.yaml     # TCP Socket Liveness Probe 테스트
│   ├── 03-liveness-exec.yaml    # Exec Command Liveness Probe 테스트
│   ├── 04-readiness-exec.yaml   # Exec Readiness Probe 테스트
│   ├── 05-readiness-http.yaml   # HTTP Readiness Probe 테스트
│   ├── 06-startup-probe.yaml    # Startup Probe 테스트
│   ├── 07-combined-probes.yaml  # 모든 프로브 조합 테스트
│   └── 08-readiness-gate.yaml   # Custom Readiness Gate 테스트
├── scripts/                      # 테스트 스크립트
│   ├── test-health-probes.sh    # 자동화된 테스트 실행 스크립트
│   └── probe-simulator.sh       # 프로브 실패 시뮬레이터
└── README.md                     # 이 문서
```

## 🚀 빠른 시작

### 사전 요구사항
- Kubernetes 클러스터 (Minikube, Kind, 또는 실제 클러스터)
- kubectl CLI 도구
- bash shell

### 실행 권한 설정
```bash
chmod +x scripts/*.sh
```

### 전체 테스트 실행
```bash
./scripts/test-health-probes.sh all
```

### 개별 테스트 실행
```bash
# Liveness Probe 테스트만
./scripts/test-health-probes.sh liveness

# Readiness Probe 테스트만
./scripts/test-health-probes.sh readiness

# Startup Probe 테스트만
./scripts/test-health-probes.sh startup

# 조합 테스트
./scripts/test-health-probes.sh combined

# 정리
./scripts/test-health-probes.sh cleanup
```

## 🧪 테스트 시나리오 상세

### 1. Liveness Probe 테스트

#### HTTP Liveness (01-liveness-http.yaml)
- Spring Boot Actuator의 `/actuator/health` 엔드포인트 사용
- 15초 후 첫 체크, 10초마다 반복
- 3번 연속 실패 시 컨테이너 재시작

#### TCP Liveness (02-liveness-tcp.yaml)
- Nginx 컨테이너의 80번 포트 체크
- 가장 간단한 형태의 liveness 체크
- 네트워크 연결만 확인

#### Exec Liveness (03-liveness-exec.yaml)
- 파일 존재 여부로 health 체크
- 30초 후 자동으로 파일 삭제되어 실패 시뮬레이션
- 컨테이너 재시작 관찰 가능

### 2. Readiness Probe 테스트

#### Exec Readiness (04-readiness-exec.yaml)
- `/tmp/random-generator-ready` 파일 체크
- 3개 레플리카의 점진적 준비 상태 관찰
- Service 엔드포인트 변화 모니터링

#### HTTP Readiness (05-readiness-http.yaml)
- `/actuator/health/readiness` 엔드포인트 사용
- 성공 threshold: 2회, 실패 threshold: 2회
- 토글 기능으로 readiness 상태 변경 가능

### 3. Startup Probe 테스트 (06-startup-probe.yaml)
- 90초의 긴 시작 시간 시뮬레이션
- 120초까지 시작 허용 (12회 시도 × 10초)
- Startup probe 성공 후 liveness/readiness probe 활성화

### 4. Combined Probes 테스트 (07-combined-probes.yaml)
- 세 가지 프로브 모두 사용
- 각 프로브의 역할 분리:
  - Startup: 초기 시작 확인
  - Liveness: 지속적인 health 체크
  - Readiness: 트래픽 수신 준비 확인

### 5. Readiness Gate 테스트 (08-readiness-gate.yaml)
- 커스텀 readiness 조건 추가
- 외부 로드밸런서 준비 등의 추가 조건 시뮬레이션

## 🛠️ Probe 시뮬레이터 사용법

```bash
./scripts/probe-simulator.sh
```

### 기능:
1. **Liveness 실패 시뮬레이션**: 선택한 Pod의 health 상태를 unhealthy로 변경
2. **Readiness 실패 시뮬레이션**: Pod를 Service endpoint에서 제거
3. **느린 시작 시뮬레이션**: Pod 재시작 후 시작 과정 모니터링
4. **메트릭 모니터링**: 실시간 probe 상태 대시보드
5. **카오스 테스팅**: 랜덤 실패 유발로 복원력 테스트

## 📊 모니터링 명령어

### Pod 상태 확인
```bash
kubectl get pods -w
```

### 이벤트 모니터링
```bash
kubectl get events --sort-by='.lastTimestamp' | grep probe
```

### 엔드포인트 확인
```bash
kubectl get endpoints -w
```

### Pod 상세 정보
```bash
kubectl describe pod <pod-name>
```

### 컨테이너 재시작 횟수
```bash
kubectl get pods -o custom-columns=NAME:.metadata.name,RESTARTS:.status.containerStatuses[0].restartCount
```

## 🎯 학습 목표

이 테스트 코드를 통해 다음을 학습할 수 있습니다:

1. **Liveness Probe 이해**
   - 언제 컨테이너가 재시작되는지
   - 다양한 체크 방법의 차이점
   - 적절한 파라미터 설정 방법

2. **Readiness Probe 이해**
   - Service endpoint 관리 메커니즘
   - 점진적 배포 시 역할
   - Liveness와의 차이점

3. **Startup Probe 이해**
   - 느린 시작 애플리케이션 처리
   - 다른 probe와의 상호작용
   - 최적 설정 방법

4. **실전 경험**
   - 실패 시나리오 경험
   - 복구 과정 관찰
   - 모니터링 및 디버깅

## ⚠️ 주의사항

1. **프로덕션 환경**: 테스트 코드는 학습 목적으로 설계되었습니다. 프로덕션에서는 더 신중한 설정이 필요합니다.

2. **리소스 제한**: 테스트 Pod들은 최소 리소스로 설정되어 있습니다. 실제 환경에서는 적절히 조정하세요.

3. **타이밍 설정**: initialDelaySeconds, periodSeconds 등은 애플리케이션 특성에 맞게 조정해야 합니다.

## 📚 참고 자료

- [Kubernetes Patterns Book](https://k8spatterns.io/)
- [Kubernetes Documentation - Configure Liveness, Readiness and Startup Probes](https://kubernetes.io/docs/tasks/configure-pod-container/configure-liveness-readiness-startup-probes/)
- [Spring Boot Actuator](https://spring.io/guides/gs/actuator-service/)

## 🤝 기여

이 프로젝트는 학습 목적으로 만들어졌습니다. 개선사항이나 버그를 발견하시면 이슈를 생성해주세요.