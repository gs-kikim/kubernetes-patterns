#!/bin/bash

# Test 3: Kubernetes 매니페스트 구조 검증 테스트
# 블로그에서 설명한 Controller 배포 패턴의 구조적 요소 검증

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MANIFEST_DIR="$SCRIPT_DIR/../manifests"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "========================================"
echo "Test 3: Kubernetes 매니페스트 구조 검증"
echo "========================================"

PASSED=0
FAILED=0

CONTROLLER_MANIFEST="$MANIFEST_DIR/config-watcher-controller.yml"
WEBAPP_MANIFEST="$MANIFEST_DIR/web-app.yml"

# 3.1 ServiceAccount 정의 확인
echo ""
echo "3.1 ServiceAccount 정의 확인"
if grep -q 'kind: ServiceAccount' "$CONTROLLER_MANIFEST"; then
    echo -e "${GREEN}[PASS]${NC} ServiceAccount 리소스 정의 존재"
    ((PASSED++))
else
    echo -e "${RED}[FAIL]${NC} ServiceAccount 리소스 정의 없음"
    ((FAILED++))
fi

# 3.2 RoleBinding 정의 확인
echo ""
echo "3.2 RoleBinding 정의 확인"
if grep -q 'kind: RoleBinding' "$CONTROLLER_MANIFEST"; then
    echo -e "${GREEN}[PASS]${NC} RoleBinding 리소스 정의 존재"
    ((PASSED++))
else
    echo -e "${RED}[FAIL]${NC} RoleBinding 리소스 정의 없음"
    ((FAILED++))
fi

# 3.3 ClusterRole 'edit' 참조 확인
echo ""
echo "3.3 ClusterRole 'edit' 참조 확인"
if grep -A5 'roleRef:' "$CONTROLLER_MANIFEST" | grep -q 'name: edit'; then
    echo -e "${GREEN}[PASS]${NC} ClusterRole 'edit' 참조 존재"
    ((PASSED++))
else
    echo -e "${RED}[FAIL]${NC} ClusterRole 'edit' 참조 없음"
    ((FAILED++))
fi

# 3.4 Ambassador 컨테이너(kubeapi-proxy) 확인
echo ""
echo "3.4 Ambassador 컨테이너(kubeapi-proxy) 확인"
if grep -q 'k8spatterns/kubeapi-proxy' "$CONTROLLER_MANIFEST"; then
    echo -e "${GREEN}[PASS]${NC} Ambassador 컨테이너(kubeapi-proxy) 정의 존재"
    ((PASSED++))
else
    echo -e "${RED}[FAIL]${NC} Ambassador 컨테이너 정의 없음"
    ((FAILED++))
fi

# 3.5 Controller 컨테이너(curl-jq) 확인
echo ""
echo "3.5 Controller 컨테이너(curl-jq) 확인"
if grep -q 'k8spatterns/curl-jq' "$CONTROLLER_MANIFEST"; then
    echo -e "${GREEN}[PASS]${NC} Controller 컨테이너(curl-jq) 정의 존재"
    ((PASSED++))
else
    echo -e "${RED}[FAIL]${NC} Controller 컨테이너 정의 없음"
    ((FAILED++))
fi

# 3.6 Downward API - WATCH_NAMESPACE 환경변수 설정 확인
echo ""
echo "3.6 Downward API - WATCH_NAMESPACE 환경변수 설정 확인"
if grep -A4 'WATCH_NAMESPACE' "$CONTROLLER_MANIFEST" | grep -q 'metadata.namespace'; then
    echo -e "${GREEN}[PASS]${NC} Downward API로 WATCH_NAMESPACE 설정"
    ((PASSED++))
else
    echo -e "${RED}[FAIL]${NC} Downward API 설정 없음"
    ((FAILED++))
fi

# 3.7 serviceAccountName 설정 확인
echo ""
echo "3.7 serviceAccountName 설정 확인"
if grep -q 'serviceAccountName: config-watcher-controller' "$CONTROLLER_MANIFEST"; then
    echo -e "${GREEN}[PASS]${NC} serviceAccountName 설정 존재"
    ((PASSED++))
else
    echo -e "${RED}[FAIL]${NC} serviceAccountName 설정 없음"
    ((FAILED++))
fi

# 3.8 ConfigMap 볼륨 마운트 확인
echo ""
echo "3.8 ConfigMap 볼륨 마운트 확인"
if grep -A2 'volumes:' "$CONTROLLER_MANIFEST" | grep -q 'configMap:'; then
    echo -e "${GREEN}[PASS]${NC} ConfigMap 볼륨 정의 존재"
    ((PASSED++))
else
    echo -e "${RED}[FAIL]${NC} ConfigMap 볼륨 정의 없음"
    ((FAILED++))
fi

# 3.9 replicas: 1 (Singleton Service 패턴) 확인
echo ""
echo "3.9 Singleton Service 패턴 (replicas: 1) 확인"
if grep -q 'replicas: 1' "$CONTROLLER_MANIFEST"; then
    echo -e "${GREEN}[PASS]${NC} Singleton Service 패턴(replicas: 1) 적용"
    ((PASSED++))
else
    echo -e "${RED}[FAIL]${NC} Singleton Service 패턴 미적용"
    ((FAILED++))
fi

# 3.10 webapp ConfigMap의 podDeleteSelector Annotation 확인
echo ""
echo "3.10 webapp ConfigMap의 podDeleteSelector Annotation 확인"
if grep -q 'k8spatterns.com/podDeleteSelector' "$WEBAPP_MANIFEST"; then
    echo -e "${GREEN}[PASS]${NC} podDeleteSelector Annotation 존재"
    ((PASSED++))
else
    echo -e "${RED}[FAIL]${NC} podDeleteSelector Annotation 없음"
    ((FAILED++))
fi

# 3.11 webapp ConfigMap과 Deployment의 label 매칭 확인
echo ""
echo "3.11 webapp ConfigMap과 Deployment의 label 매칭 확인"
ANNOTATION_SELECTOR=$(grep 'podDeleteSelector' "$WEBAPP_MANIFEST" | sed 's/.*: "\(.*\)"/\1/')
if grep -q "app: webapp" "$WEBAPP_MANIFEST"; then
    echo -e "${GREEN}[PASS]${NC} Label 선택자($ANNOTATION_SELECTOR)와 Pod Label 매칭"
    ((PASSED++))
else
    echo -e "${RED}[FAIL]${NC} Label 선택자 불일치"
    ((FAILED++))
fi

# 3.12 ConfigMap 환경변수 참조 확인
echo ""
echo "3.12 webapp의 ConfigMap 환경변수 참조 확인"
if grep -A4 'configMapKeyRef:' "$WEBAPP_MANIFEST" | grep -q 'name: webapp-config'; then
    echo -e "${GREEN}[PASS]${NC} ConfigMap 환경변수 참조 존재"
    ((PASSED++))
else
    echo -e "${RED}[FAIL]${NC} ConfigMap 환경변수 참조 없음"
    ((FAILED++))
fi

echo ""
echo "========================================"
echo "결과: ${PASSED} 통과, ${FAILED} 실패"
echo "========================================"

if [ $FAILED -gt 0 ]; then
    exit 1
fi
