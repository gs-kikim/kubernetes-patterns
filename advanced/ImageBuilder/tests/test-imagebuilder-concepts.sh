#!/bin/bash

# Test 3: 블로그 핵심 개념 검증 테스트
# Chapter 30: ImageBuilder 블로그에서 다룬 핵심 개념들이 매니페스트에 반영되었는지 검증

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MANIFEST_DIR="$SCRIPT_DIR/../manifests"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo "========================================"
echo "Test 3: 블로그 핵심 개념 검증"
echo "========================================"

PASSED=0
FAILED=0

CONFIGMAP="$MANIFEST_DIR/build-context-configmap.yml"
KANIKO="$MANIFEST_DIR/kaniko-build-job.yml"
BUILDKIT_DAEMONLESS="$MANIFEST_DIR/buildkit-daemonless-job.yml"
BUILDKIT_DAEMON="$MANIFEST_DIR/buildkit-daemon-deployment.yml"
BUILDKIT_CLIENT="$MANIFEST_DIR/buildkit-build-job.yml"
VERIFY="$MANIFEST_DIR/verify-deployment.yml"

# === 개념 1: Kubernetes 내부 이미지 빌드의 필요성 ===
echo ""
echo -e "${BLUE}[개념 1] Kubernetes 내부 이미지 빌드 — 빌드 컨텍스트와 Job 패턴${NC}"
echo "  외부 CI/CD 없이 클러스터 내부에서 이미지를 빌드하는 패턴"
echo ""

echo "3.1.1 ConfigMap으로 빌드 컨텍스트 패키징 (hostPath 의존성 제거)"
if grep -q 'kind: ConfigMap' "$CONFIGMAP" && grep -q 'Dockerfile:' "$CONFIGMAP"; then
    echo -e "${GREEN}[PASS]${NC} ConfigMap에 Dockerfile 포함 — 모든 환경에서 이식 가능"
    ((PASSED++))
else
    echo -e "${RED}[FAIL]${NC} ConfigMap 빌드 컨텍스트 미구성"
    ((FAILED++))
fi

echo "3.1.2 Job 리소스로 일회성 빌드 작업 수행"
if grep -q 'kind: Job' "$KANIKO" && grep -q 'restartPolicy: Never' "$KANIKO"; then
    echo -e "${GREEN}[PASS]${NC} Job + restartPolicy: Never — 빌드 완료 후 종료"
    ((PASSED++))
else
    echo -e "${RED}[FAIL]${NC} Job 패턴 미적용"
    ((FAILED++))
fi

echo "3.1.3 initContainers로 빌드 컨텍스트 준비 (관심사 분리)"
if grep -q 'initContainers:' "$KANIKO" && grep -q 'prepare-context' "$KANIKO"; then
    echo -e "${GREEN}[PASS]${NC} initContainer로 ConfigMap → workspace 복사 (관심사 분리)"
    ((PASSED++))
else
    echo -e "${RED}[FAIL]${NC} initContainers 빌드 컨텍스트 준비 없음"
    ((FAILED++))
fi

# === 개념 2: Kaniko — Docker daemon 없는 이미지 빌드 ===
echo ""
echo -e "${BLUE}[개념 2] Kaniko — Docker daemon 없는 사용자 공간 이미지 빌드${NC}"
echo "  Google 아카이브(2025.06), Chainguard 포크 유지 중"
echo ""

echo "3.2.1 gcr.io/kaniko-project/executor 이미지 사용"
if grep -q 'gcr.io/kaniko-project/executor' "$KANIKO"; then
    echo -e "${GREEN}[PASS]${NC} Kaniko 공식 executor 이미지 사용"
    ((PASSED++))
else
    echo -e "${RED}[FAIL]${NC} Kaniko executor 이미지 미사용"
    ((FAILED++))
fi

echo "3.2.2 --insecure 플래그로 HTTP 레지스트리 지원"
if grep -q '\-\-insecure' "$KANIKO"; then
    echo -e "${GREEN}[PASS]${NC} --insecure로 minikube HTTP 레지스트리 push 가능"
    ((PASSED++))
else
    echo -e "${RED}[FAIL]${NC} --insecure 미설정 — HTTP 레지스트리 push 불가"
    ((FAILED++))
fi

echo "3.2.3 dir:// 로컬 디렉토리 빌드 컨텍스트"
if grep -q 'context=dir://' "$KANIKO"; then
    echo -e "${GREEN}[PASS]${NC} dir:// 프로토콜로 로컬 빌드 컨텍스트 참조"
    ((PASSED++))
else
    echo -e "${RED}[FAIL]${NC} dir:// 빌드 컨텍스트 미설정"
    ((FAILED++))
fi

# === 개념 3: BuildKit — 차세대 표준 빌드 엔진 ===
echo ""
echo -e "${BLUE}[개념 3] BuildKit — 2025-2026 사실상 표준 빌드 엔진${NC}"
echo "  DAG 기반 병렬 빌드, 콘텐츠 주소 캐시, 시크릿 마운트"
echo ""

echo "3.3.1 moby/buildkit 공식 이미지 사용"
if grep -q 'moby/buildkit' "$BUILDKIT_DAEMONLESS"; then
    echo -e "${GREEN}[PASS]${NC} moby/buildkit 공식 이미지 사용"
    ((PASSED++))
else
    echo -e "${RED}[FAIL]${NC} moby/buildkit 이미지 미사용"
    ((FAILED++))
fi

echo "3.3.2 buildctl-daemonless.sh 단발성 빌드 지원"
if grep -q 'buildctl-daemonless.sh' "$BUILDKIT_DAEMONLESS"; then
    echo -e "${GREEN}[PASS]${NC} daemonless.sh — 임시 데몬 시작/빌드/종료 패턴"
    ((PASSED++))
else
    echo -e "${RED}[FAIL]${NC} buildctl-daemonless.sh 미사용"
    ((FAILED++))
fi

echo "3.3.3 --frontend=dockerfile.v0 Dockerfile 프론트엔드 사용"
if grep -q 'frontend=dockerfile.v0' "$BUILDKIT_DAEMONLESS"; then
    echo -e "${GREEN}[PASS]${NC} Dockerfile 프론트엔드 — 표준 Dockerfile 빌드"
    ((PASSED++))
else
    echo -e "${RED}[FAIL]${NC} Dockerfile 프론트엔드 미설정"
    ((FAILED++))
fi

echo "3.3.4 type=image,...,push=true 출력 형식 지정"
if grep -q 'type=image' "$BUILDKIT_DAEMONLESS" && grep -q 'push=true' "$BUILDKIT_DAEMONLESS"; then
    echo -e "${GREEN}[PASS]${NC} 이미지 출력 + 레지스트리 push 설정"
    ((PASSED++))
else
    echo -e "${RED}[FAIL]${NC} 출력 형식 미설정"
    ((FAILED++))
fi

# === 개념 4: BuildKit Daemon 모드 — 공유 빌드 인프라 ===
echo ""
echo -e "${BLUE}[개념 4] BuildKit Daemon — 장기 실행 공유 빌드 인프라${NC}"
echo "  빌드 캐시 유지, 여러 클라이언트 공유, 프로덕션 빌드 서비스"
echo ""

echo "3.4.1 Deployment로 장기 실행 데몬 배포"
if grep -q 'kind: Deployment' "$BUILDKIT_DAEMON" && grep -q 'buildkitd' "$BUILDKIT_DAEMON"; then
    echo -e "${GREEN}[PASS]${NC} Deployment로 buildkitd 데몬 배포"
    ((PASSED++))
else
    echo -e "${RED}[FAIL]${NC} BuildKit Daemon Deployment 미정의"
    ((FAILED++))
fi

echo "3.4.2 Service로 클러스터 내 빌드 API 노출"
if grep -q 'kind: Service' "$BUILDKIT_DAEMON" && grep -q '1234' "$BUILDKIT_DAEMON"; then
    echo -e "${GREEN}[PASS]${NC} Service로 buildkitd gRPC API 노출 (포트 1234)"
    ((PASSED++))
else
    echo -e "${RED}[FAIL]${NC} BuildKit Daemon Service 미정의"
    ((FAILED++))
fi

echo "3.4.3 BUILDKIT_HOST 환경변수로 클라이언트-데몬 연결"
if grep -q 'BUILDKIT_HOST' "$BUILDKIT_CLIENT" && grep -q 'tcp://buildkitd:1234' "$BUILDKIT_CLIENT"; then
    echo -e "${GREEN}[PASS]${NC} BUILDKIT_HOST=tcp://buildkitd:1234 — 데몬 주소 지정"
    ((PASSED++))
else
    echo -e "${RED}[FAIL]${NC} BUILDKIT_HOST 환경변수 미설정"
    ((FAILED++))
fi

# === 개념 5: 내장 레지스트리 활용 ===
echo ""
echo -e "${BLUE}[개념 5] 내장 레지스트리 — 클러스터 내부 이미지 저장소${NC}"
echo "  minikube registry addon, insecure HTTP 레지스트리"
echo ""

echo "3.5.1 registry.kube-system.svc.cluster.local 주소 사용"
if grep -q 'registry.kube-system.svc.cluster.local' "$KANIKO"; then
    echo -e "${GREEN}[PASS]${NC} minikube 내장 레지스트리 주소 사용"
    ((PASSED++))
else
    echo -e "${RED}[FAIL]${NC} 내장 레지스트리 주소 미사용"
    ((FAILED++))
fi

echo "3.5.2 빌드된 이미지를 Deployment에서 직접 참조"
if grep -q 'registry.kube-system.svc.cluster.local/imagebuilder-test' "$VERIFY"; then
    echo -e "${GREEN}[PASS]${NC} 빌드 이미지를 Deployment에서 직접 참조 (Pull 가능)"
    ((PASSED++))
else
    echo -e "${RED}[FAIL]${NC} 빌드 이미지 Deployment 참조 없음"
    ((FAILED++))
fi

echo "3.5.3 insecure registry 설정 (HTTP push/pull)"
INSECURE_COUNT=0
grep -q 'insecure' "$KANIKO" && ((INSECURE_COUNT++)) || true
grep -q 'registry.insecure=true' "$BUILDKIT_DAEMONLESS" && ((INSECURE_COUNT++)) || true
if [ "$INSECURE_COUNT" -ge 2 ]; then
    echo -e "${GREEN}[PASS]${NC} Kaniko + BuildKit 모두 insecure 레지스트리 설정 ($INSECURE_COUNT/2)"
    ((PASSED++))
else
    echo -e "${RED}[FAIL]${NC} insecure 설정 불완전 ($INSECURE_COUNT/2)"
    ((FAILED++))
fi

# === 개념 6: 빌드 엔진 비교 ===
echo ""
echo -e "${BLUE}[개념 6] 빌드 엔진 비교 — Kaniko vs BuildKit${NC}"
echo "  Kaniko: privileged 불필요, 순차 빌드 / BuildKit: privileged 필요, 병렬 DAG 빌드"
echo ""

echo "3.6.1 Kaniko — privileged 불필요 (사용자 공간 빌드)"
if ! grep -q 'privileged:' "$KANIKO"; then
    echo -e "${GREEN}[PASS]${NC} Kaniko Job에 privileged 미설정 — 제한된 환경에서도 실행 가능"
    ((PASSED++))
else
    echo -e "${RED}[FAIL]${NC} Kaniko에 불필요한 privileged 설정 발견"
    ((FAILED++))
fi

echo "3.6.2 BuildKit — privileged 필요 (커널 네임스페이스 사용)"
if grep -q 'privileged: true' "$BUILDKIT_DAEMONLESS"; then
    echo -e "${GREEN}[PASS]${NC} BuildKit daemonless에 privileged: true — 표준 모드 필수"
    ((PASSED++))
else
    echo -e "${RED}[FAIL]${NC} BuildKit에 privileged 미설정"
    ((FAILED++))
fi

echo ""
echo "========================================"
echo "결과: ${PASSED} 통과, ${FAILED} 실패"
echo "========================================"

if [ $FAILED -gt 0 ]; then
    exit 1
fi
