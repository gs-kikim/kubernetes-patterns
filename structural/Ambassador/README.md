# Ambassador Pattern - 테스트 가이드

## 개요

Ambassador 패턴은 외부 서비스에 대한 접근을 프록시하고 복잡성을 숨기는 특수한 사이드카 컨테이너 패턴입니다.
이 디렉토리에는 Ambassador 패턴의 다양한 측면을 검증하는 종합 테스트가 포함되어 있습니다.

## 테스트 시나리오

### Test 1: 기본 Ambassador 패턴 - 로그 프록시
**목적**: Ambassador가 메인 애플리케이션의 로그를 프록시하는 기본 동작 검증

**검증 항목**:
- Pod 내 두 컨테이너(main, ambassador) 정상 실행
- 메인 컨테이너가 localhost:9009로 로그 전송
- Ambassador가 로그를 수신하고 처리
- 외부에서 메인 애플리케이션 접근 가능 (포트 8080)

### Test 2: localhost 통신 검증
**목적**: Pod 내 컨테이너 간 localhost를 통한 통신 확인

**검증 항목**:
- 메인 컨테이너에서 curl localhost:9009 성공
- Ambassador 컨테이너 로그에 요청 기록 확인
- 네트워크 네임스페이스 공유 확인

### Test 3: HTTP 프록시 Ambassador
**목적**: 외부 HTTP 서비스를 프록시하는 Ambassador 테스트

**검증 항목**:
- Nginx/Envoy를 Ambassador로 사용
- 메인 앱이 localhost를 통해 외부 API 접근
- 타임아웃, 재시도 정책 적용 확인
- 서킷 브레이커 동작 검증

### Test 4: 환경별 백엔드 전환
**목적**: 동일한 메인 컨테이너로 환경별 다른 백엔드 접근

**검증 항목**:
- 개발 환경: 로컬 캐시 서버 사용
- 프로덕션 환경: 클러스터 캐시 사용
- 메인 컨테이너 코드 변경 없이 Ambassador만 교체
- ConfigMap을 통한 환경별 설정 주입

### Test 5: Ambassador 장애 복구
**목적**: Ambassador 컨테이너 장애 시 복구 메커니즘 검증

**검증 항목**:
- Ambassador 프로세스 종료 시 자동 재시작
- 재시작 중 메인 컨테이너 동작
- 복구 후 정상 통신 재개
- RESTARTS 카운트 증가 확인

### Test 6: Native Sidecar 시작 순서 (Kubernetes 1.28+)
**목적**: Native Sidecar의 시작/종료 순서 보장 검증

**검증 항목**:
- Ambassador가 메인 컨테이너보다 먼저 시작
- startupProbe를 통한 준비 완료 확인
- 메인 컨테이너 종료 시 Ambassador에 SIGTERM 전달
- Pod 종료 순서 검증

### Test 7: 리소스 격리 및 보안
**목적**: Ambassador를 통한 보안 강화 검증

**검증 항목**:
- 메인 컨테이너는 외부 직접 접근 불가
- Ambassador만 외부 통신 가능
- TLS 종료를 Ambassador에서 처리
- 리소스 요청/제한 적용 확인

## 디렉토리 구조

```
Ambassador/
├── README.md                    # 이 파일
├── manifests/                   # Kubernetes 매니페스트
│   ├── test1-basic-log-proxy.yaml
│   ├── test2-localhost-verify.yaml
│   ├── test3-http-proxy.yaml
│   ├── test4-env-backend-dev.yaml
│   ├── test4-env-backend-prod.yaml
│   ├── test5-failure-recovery.yaml
│   ├── test6-native-sidecar.yaml
│   └── test7-security.yaml
├── tests/                       # 테스트 자동화 스크립트
│   ├── run-all-tests.sh
│   ├── test1-basic.sh
│   ├── test2-localhost.sh
│   ├── test3-http-proxy.sh
│   ├── test4-env-backend.sh
│   ├── test5-failure.sh
│   ├── test6-native-sidecar.sh
│   ├── test7-security.sh
│   └── test-utils.sh
└── images/                      # 커스텀 이미지 (필요시)
    └── http-ambassador/
        └── Dockerfile

## 사전 요구사항

- Minikube 실행 중
- kubectl 설치 및 구성
- Kubernetes 1.28+ (Native Sidecar 테스트용)

## 테스트 실행

### 전체 테스트 실행
```bash
cd structural/Ambassador/tests
./run-all-tests.sh
```

### 개별 테스트 실행
```bash
cd structural/Ambassador/tests
./test1-basic.sh
./test2-localhost.sh
# ... 등등
```

## 테스트 결과

각 테스트는 다음 정보를 출력합니다:
- 테스트 이름 및 설명
- 검증 단계별 결과 (PASS/FAIL)
- 실패 시 상세 에러 메시지
- 리소스 정리 상태

최종 결과는 `test-results.md` 파일에 저장됩니다.

## 참고 자료

- [Kubernetes Patterns - Ambassador Pattern](https://k8spatterns.io/)
- [Original Example Repository](https://github.com/k8spatterns/examples/tree/main/structural/Ambassador)
- [Native Sidecar Containers](https://kubernetes.io/docs/concepts/workloads/pods/sidecar-containers/)
