#!/bin/bash

# Test 2: Kubernetes 매니페스트 구조 검증 테스트
# ImageBuilder 패턴의 매니페스트가 올바른 구조를 갖추고 있는지 검증

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MANIFEST_DIR="$SCRIPT_DIR/../manifests"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "========================================"
echo "Test 2: 매니페스트 구조 검증"
echo "========================================"

PASSED=0
FAILED=0

CONFIGMAP="$MANIFEST_DIR/build-context-configmap.yml"
KANIKO="$MANIFEST_DIR/kaniko-build-job.yml"
BUILDKIT_DAEMONLESS="$MANIFEST_DIR/buildkit-daemonless-job.yml"
BUILDKIT_DAEMON="$MANIFEST_DIR/buildkit-daemon-deployment.yml"
BUILDKIT_CLIENT="$MANIFEST_DIR/buildkit-build-job.yml"
VERIFY="$MANIFEST_DIR/verify-deployment.yml"

# === ConfigMap 구조 검증 ===
echo ""
echo "--- ConfigMap (빌드 컨텍스트) 구조 검증 ---"

echo ""
echo "2.1 ConfigMap 리소스 정의 확인"
if grep -q 'kind: ConfigMap' "$CONFIGMAP"; then
    echo -e "${GREEN}[PASS]${NC} ConfigMap 리소스 정의 존재"
    ((PASSED++))
else
    echo -e "${RED}[FAIL]${NC} ConfigMap 리소스 정의 없음"
    ((FAILED++))
fi

echo ""
echo "2.2 Dockerfile 키 존재 확인"
if grep -q 'Dockerfile:' "$CONFIGMAP"; then
    echo -e "${GREEN}[PASS]${NC} Dockerfile 키 정의됨"
    ((PASSED++))
else
    echo -e "${RED}[FAIL]${NC} Dockerfile 키 없음"
    ((FAILED++))
fi

echo ""
echo "2.3 index.html 키 존재 확인"
if grep -q 'index.html:' "$CONFIGMAP"; then
    echo -e "${GREEN}[PASS]${NC} index.html 키 정의됨"
    ((PASSED++))
else
    echo -e "${RED}[FAIL]${NC} index.html 키 없음"
    ((FAILED++))
fi

echo ""
echo "2.4 nginx 베이스 이미지 확인"
if grep -q 'nginx:1.27-alpine' "$CONFIGMAP"; then
    echo -e "${GREEN}[PASS]${NC} nginx:1.27-alpine 베이스 이미지 사용"
    ((PASSED++))
else
    echo -e "${RED}[FAIL]${NC} nginx 베이스 이미지 미확인"
    ((FAILED++))
fi

# === Kaniko Job 구조 검증 ===
echo ""
echo "--- Kaniko Job 구조 검증 ---"

echo ""
echo "2.5 Kaniko Job 리소스 정의 확인"
if grep -q 'kind: Job' "$KANIKO"; then
    echo -e "${GREEN}[PASS]${NC} Job 리소스 정의 존재"
    ((PASSED++))
else
    echo -e "${RED}[FAIL]${NC} Job 리소스 정의 없음"
    ((FAILED++))
fi

echo ""
echo "2.6 Kaniko executor 이미지 확인"
if grep -q 'kaniko-project/executor' "$KANIKO"; then
    echo -e "${GREEN}[PASS]${NC} gcr.io/kaniko-project/executor 이미지 사용"
    ((PASSED++))
else
    echo -e "${RED}[FAIL]${NC} Kaniko executor 이미지 미확인"
    ((FAILED++))
fi

echo ""
echo "2.7 --insecure 플래그 확인 (minikube HTTP 레지스트리)"
if grep -q '\-\-insecure' "$KANIKO"; then
    echo -e "${GREEN}[PASS]${NC} --insecure 플래그 설정됨"
    ((PASSED++))
else
    echo -e "${RED}[FAIL]${NC} --insecure 플래그 없음"
    ((FAILED++))
fi

echo ""
echo "2.8 --destination 내부 레지스트리 확인"
if grep -q 'registry.kube-system.svc.cluster.local' "$KANIKO"; then
    echo -e "${GREEN}[PASS]${NC} 내부 레지스트리 주소 설정됨"
    ((PASSED++))
else
    echo -e "${RED}[FAIL]${NC} 내부 레지스트리 주소 미설정"
    ((FAILED++))
fi

echo ""
echo "2.9 initContainers 빌드 컨텍스트 준비 확인"
if grep -q 'initContainers:' "$KANIKO"; then
    echo -e "${GREEN}[PASS]${NC} initContainers로 빌드 컨텍스트 준비"
    ((PASSED++))
else
    echo -e "${RED}[FAIL]${NC} initContainers 미정의"
    ((FAILED++))
fi

# === BuildKit Daemonless Job 구조 검증 ===
echo ""
echo "--- BuildKit Daemonless Job 구조 검증 ---"

echo ""
echo "2.10 BuildKit Daemonless Job 리소스 정의 확인"
if grep -q 'kind: Job' "$BUILDKIT_DAEMONLESS"; then
    echo -e "${GREEN}[PASS]${NC} Job 리소스 정의 존재"
    ((PASSED++))
else
    echo -e "${RED}[FAIL]${NC} Job 리소스 정의 없음"
    ((FAILED++))
fi

echo ""
echo "2.11 moby/buildkit 이미지 확인"
if grep -q 'moby/buildkit' "$BUILDKIT_DAEMONLESS"; then
    echo -e "${GREEN}[PASS]${NC} moby/buildkit 이미지 사용"
    ((PASSED++))
else
    echo -e "${RED}[FAIL]${NC} moby/buildkit 이미지 미확인"
    ((FAILED++))
fi

echo ""
echo "2.12 buildctl-daemonless.sh 명령 확인"
if grep -q 'buildctl-daemonless.sh' "$BUILDKIT_DAEMONLESS"; then
    echo -e "${GREEN}[PASS]${NC} buildctl-daemonless.sh 사용"
    ((PASSED++))
else
    echo -e "${RED}[FAIL]${NC} buildctl-daemonless.sh 미사용"
    ((FAILED++))
fi

echo ""
echo "2.13 registry.insecure=true 출력 옵션 확인"
if grep -q 'registry.insecure=true' "$BUILDKIT_DAEMONLESS"; then
    echo -e "${GREEN}[PASS]${NC} insecure registry 출력 설정됨"
    ((PASSED++))
else
    echo -e "${RED}[FAIL]${NC} insecure registry 출력 미설정"
    ((FAILED++))
fi

echo ""
echo "2.14 privileged 보안 컨텍스트 확인"
if grep -q 'privileged: true' "$BUILDKIT_DAEMONLESS"; then
    echo -e "${GREEN}[PASS]${NC} privileged: true 설정 (BuildKit 필수)"
    ((PASSED++))
else
    echo -e "${RED}[FAIL]${NC} privileged 미설정"
    ((FAILED++))
fi

# === BuildKit Daemon Deployment 구조 검증 ===
echo ""
echo "--- BuildKit Daemon (Deployment + Service) 구조 검증 ---"

echo ""
echo "2.15 BuildKit Daemon Deployment 확인"
if grep -q 'kind: Deployment' "$BUILDKIT_DAEMON"; then
    echo -e "${GREEN}[PASS]${NC} Deployment 리소스 정의 존재"
    ((PASSED++))
else
    echo -e "${RED}[FAIL]${NC} Deployment 리소스 정의 없음"
    ((FAILED++))
fi

echo ""
echo "2.16 BuildKit Daemon Service 확인"
if grep -q 'kind: Service' "$BUILDKIT_DAEMON"; then
    echo -e "${GREEN}[PASS]${NC} Service 리소스 정의 존재"
    ((PASSED++))
else
    echo -e "${RED}[FAIL]${NC} Service 리소스 정의 없음"
    ((FAILED++))
fi

echo ""
echo "2.17 BuildKit Daemon 포트 (1234) 확인"
if grep -q '1234' "$BUILDKIT_DAEMON"; then
    echo -e "${GREEN}[PASS]${NC} 포트 1234 설정됨"
    ((PASSED++))
else
    echo -e "${RED}[FAIL]${NC} 포트 1234 미설정"
    ((FAILED++))
fi

echo ""
echo "2.18 readinessProbe 확인"
if grep -q 'readinessProbe:' "$BUILDKIT_DAEMON"; then
    echo -e "${GREEN}[PASS]${NC} readinessProbe 정의됨"
    ((PASSED++))
else
    echo -e "${RED}[FAIL]${NC} readinessProbe 미정의"
    ((FAILED++))
fi

# === BuildKit Client Job 구조 검증 ===
echo ""
echo "--- BuildKit Client Job 구조 검증 ---"

echo ""
echo "2.19 BuildKit Client Job 리소스 정의 확인"
if grep -q 'kind: Job' "$BUILDKIT_CLIENT"; then
    echo -e "${GREEN}[PASS]${NC} Job 리소스 정의 존재"
    ((PASSED++))
else
    echo -e "${RED}[FAIL]${NC} Job 리소스 정의 없음"
    ((FAILED++))
fi

echo ""
echo "2.20 BUILDKIT_HOST 환경변수 확인"
if grep -q 'BUILDKIT_HOST' "$BUILDKIT_CLIENT"; then
    echo -e "${GREEN}[PASS]${NC} BUILDKIT_HOST 환경변수 설정됨"
    ((PASSED++))
else
    echo -e "${RED}[FAIL]${NC} BUILDKIT_HOST 미설정"
    ((FAILED++))
fi

echo ""
echo "2.21 buildctl 명령 사용 확인"
if grep -q 'buildctl' "$BUILDKIT_CLIENT"; then
    echo -e "${GREEN}[PASS]${NC} buildctl 명령 사용"
    ((PASSED++))
else
    echo -e "${RED}[FAIL]${NC} buildctl 미사용"
    ((FAILED++))
fi

# === Verify Deployment 구조 검증 ===
echo ""
echo "--- Verify Deployment 구조 검증 ---"

echo ""
echo "2.22 Verify Deployment 리소스 정의 확인"
if grep -q 'kind: Deployment' "$VERIFY"; then
    echo -e "${GREEN}[PASS]${NC} Deployment 리소스 정의 존재"
    ((PASSED++))
else
    echo -e "${RED}[FAIL]${NC} Deployment 리소스 정의 없음"
    ((FAILED++))
fi

echo ""
echo "2.23 Verify Service 리소스 정의 확인"
if grep -q 'kind: Service' "$VERIFY"; then
    echo -e "${GREEN}[PASS]${NC} Service 리소스 정의 존재"
    ((PASSED++))
else
    echo -e "${RED}[FAIL]${NC} Service 리소스 정의 없음"
    ((FAILED++))
fi

echo ""
echo "2.24 내부 레지스트리 이미지 참조 확인"
if grep -q 'registry.kube-system.svc.cluster.local/imagebuilder-test' "$VERIFY"; then
    echo -e "${GREEN}[PASS]${NC} 내부 레지스트리 이미지 참조"
    ((PASSED++))
else
    echo -e "${RED}[FAIL]${NC} 내부 레지스트리 이미지 미참조"
    ((FAILED++))
fi

echo ""
echo "2.25 containerPort 80 확인"
if grep -q 'containerPort: 80' "$VERIFY"; then
    echo -e "${GREEN}[PASS]${NC} containerPort: 80 정의됨"
    ((PASSED++))
else
    echo -e "${RED}[FAIL]${NC} containerPort 미정의"
    ((FAILED++))
fi

# === 크로스 매니페스트 일관성 검증 ===
echo ""
echo "--- 크로스 매니페스트 일관성 검증 ---"

echo ""
echo "2.26 모든 빌더 Job에 pattern: ImageBuilder 레이블 확인"
LABEL_COUNT=0
for f in "$KANIKO" "$BUILDKIT_DAEMONLESS" "$BUILDKIT_CLIENT" "$BUILDKIT_DAEMON" "$VERIFY"; do
    if grep -q 'pattern: ImageBuilder' "$f"; then
        ((LABEL_COUNT++))
    fi
done
if [ "$LABEL_COUNT" -eq 5 ]; then
    echo -e "${GREEN}[PASS]${NC} 모든 매니페스트에 pattern: ImageBuilder 레이블 존재 ($LABEL_COUNT/5)"
    ((PASSED++))
else
    echo -e "${RED}[FAIL]${NC} pattern: ImageBuilder 레이블 불일치 ($LABEL_COUNT/5)"
    ((FAILED++))
fi

echo ""
echo "========================================"
echo "결과: ${PASSED} 통과, ${FAILED} 실패"
echo "========================================"

if [ $FAILED -gt 0 ]; then
    exit 1
fi
