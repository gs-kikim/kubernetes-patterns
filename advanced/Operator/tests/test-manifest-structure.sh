#!/bin/bash

# Test 4: Kubernetes 매니페스트 구조 검증 테스트
# Operator 패턴의 구조적 요소 검증

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MANIFEST_DIR="$SCRIPT_DIR/../manifests"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "========================================"
echo "Test 4: Kubernetes 매니페스트 구조 검증"
echo "========================================"

PASSED=0
FAILED=0

OPERATOR_MANIFEST="$MANIFEST_DIR/config-watcher-operator.yml"
WEBAPP_MANIFEST="$MANIFEST_DIR/web-app.yml"
CRD_MANIFEST="$MANIFEST_DIR/config-watcher-crd.yml"
SAMPLE_MANIFEST="$MANIFEST_DIR/config-watcher-sample.yml"

# 4.1 ServiceAccount 정의 확인
echo ""
echo "4.1 ServiceAccount 정의 확인"
if grep -q 'kind: ServiceAccount' "$OPERATOR_MANIFEST"; then
    echo -e "${GREEN}[PASS]${NC} ServiceAccount 리소스 정의 존재"
    ((PASSED++))
else
    echo -e "${RED}[FAIL]${NC} ServiceAccount 리소스 정의 없음"
    ((FAILED++))
fi

# 4.2 ServiceAccount 이름 확인
echo ""
echo "4.2 ServiceAccount 이름 확인 (config-watcher-operator)"
if grep -q 'name: config-watcher-operator' "$OPERATOR_MANIFEST"; then
    echo -e "${GREEN}[PASS]${NC} ServiceAccount 이름: config-watcher-operator"
    ((PASSED++))
else
    echo -e "${RED}[FAIL]${NC} ServiceAccount 이름이 올바르지 않음"
    ((FAILED++))
fi

# 4.3 RoleBinding 정의 확인
echo ""
echo "4.3 RoleBinding 정의 확인"
if grep -q 'kind: RoleBinding' "$OPERATOR_MANIFEST"; then
    echo -e "${GREEN}[PASS]${NC} RoleBinding 리소스 정의 존재"
    ((PASSED++))
else
    echo -e "${RED}[FAIL]${NC} RoleBinding 리소스 정의 없음"
    ((FAILED++))
fi

# 4.4 ClusterRole 'edit' 참조 확인
echo ""
echo "4.4 ClusterRole 'edit' 참조 확인"
if grep -A5 'roleRef:' "$OPERATOR_MANIFEST" | grep -q 'name: edit'; then
    echo -e "${GREEN}[PASS]${NC} ClusterRole 'edit' 참조 존재"
    ((PASSED++))
else
    echo -e "${RED}[FAIL]${NC} ClusterRole 'edit' 참조 없음"
    ((FAILED++))
fi

# 4.5 CRD 전용 ClusterRole 확인
echo ""
echo "4.5 CRD 전용 ClusterRole 확인 (config-watcher-crd)"
if grep -q 'kind: ClusterRole' "$OPERATOR_MANIFEST" && grep -q 'name: config-watcher-crd' "$OPERATOR_MANIFEST"; then
    echo -e "${GREEN}[PASS]${NC} CRD 전용 ClusterRole 정의 존재"
    ((PASSED++))
else
    echo -e "${RED}[FAIL]${NC} CRD 전용 ClusterRole 없음"
    ((FAILED++))
fi

# 4.6 CRD ClusterRole에 configwatchers 리소스 권한 확인
echo ""
echo "4.6 CRD ClusterRole에 configwatchers 리소스 권한 확인"
if grep -q 'configwatchers' "$OPERATOR_MANIFEST"; then
    echo -e "${GREEN}[PASS]${NC} configwatchers 리소스 권한 존재"
    ((PASSED++))
else
    echo -e "${RED}[FAIL]${NC} configwatchers 리소스 권한 없음"
    ((FAILED++))
fi

# 4.7 CRD ClusterRole에 k8spatterns.com API 그룹 확인
echo ""
echo "4.7 CRD ClusterRole에 k8spatterns.com API 그룹 확인"
if grep -q 'k8spatterns.com' "$OPERATOR_MANIFEST"; then
    echo -e "${GREEN}[PASS]${NC} k8spatterns.com API 그룹 참조 존재"
    ((PASSED++))
else
    echo -e "${RED}[FAIL]${NC} k8spatterns.com API 그룹 참조 없음"
    ((FAILED++))
fi

# 4.8 Ambassador 컨테이너(kubeapi-proxy) 확인
echo ""
echo "4.8 Ambassador 컨테이너(kubeapi-proxy) 확인"
if grep -q 'k8spatterns/kubeapi-proxy' "$OPERATOR_MANIFEST"; then
    echo -e "${GREEN}[PASS]${NC} Ambassador 컨테이너(kubeapi-proxy) 정의 존재"
    ((PASSED++))
else
    echo -e "${RED}[FAIL]${NC} Ambassador 컨테이너 정의 없음"
    ((FAILED++))
fi

# 4.9 Operator 컨테이너(curl-jq) 확인
echo ""
echo "4.9 Operator 컨테이너(curl-jq) 확인"
if grep -q 'k8spatterns/curl-jq' "$OPERATOR_MANIFEST"; then
    echo -e "${GREEN}[PASS]${NC} Operator 컨테이너(curl-jq) 정의 존재"
    ((PASSED++))
else
    echo -e "${RED}[FAIL]${NC} Operator 컨테이너 정의 없음"
    ((FAILED++))
fi

# 4.10 Downward API - WATCH_NAMESPACE 환경변수 설정 확인
echo ""
echo "4.10 Downward API - WATCH_NAMESPACE 환경변수 설정 확인"
if grep -A4 'WATCH_NAMESPACE' "$OPERATOR_MANIFEST" | grep -q 'metadata.namespace'; then
    echo -e "${GREEN}[PASS]${NC} Downward API로 WATCH_NAMESPACE 설정"
    ((PASSED++))
else
    echo -e "${RED}[FAIL]${NC} Downward API 설정 없음"
    ((FAILED++))
fi

# 4.11 serviceAccountName 설정 확인
echo ""
echo "4.11 serviceAccountName 설정 확인"
if grep -q 'serviceAccountName: config-watcher-operator' "$OPERATOR_MANIFEST"; then
    echo -e "${GREEN}[PASS]${NC} serviceAccountName 설정 존재"
    ((PASSED++))
else
    echo -e "${RED}[FAIL]${NC} serviceAccountName 설정 없음"
    ((FAILED++))
fi

# 4.12 ConfigMap 볼륨 마운트 확인
echo ""
echo "4.12 ConfigMap 볼륨 마운트 확인"
if grep -A2 'volumes:' "$OPERATOR_MANIFEST" | grep -q 'configMap:'; then
    echo -e "${GREEN}[PASS]${NC} ConfigMap 볼륨 정의 존재"
    ((PASSED++))
else
    echo -e "${RED}[FAIL]${NC} ConfigMap 볼륨 정의 없음"
    ((FAILED++))
fi

# 4.13 Singleton 패턴 (replicas: 1) 확인
echo ""
echo "4.13 Singleton Service 패턴 (replicas: 1) 확인"
if grep -q 'replicas: 1' "$OPERATOR_MANIFEST"; then
    echo -e "${GREEN}[PASS]${NC} Singleton Service 패턴(replicas: 1) 적용"
    ((PASSED++))
else
    echo -e "${RED}[FAIL]${NC} Singleton Service 패턴 미적용"
    ((FAILED++))
fi

# 4.14 Operator 라벨 확인 (pattern: Operator)
echo ""
echo "4.14 Operator 라벨 확인 (pattern: Operator)"
if grep -q 'pattern: Operator' "$OPERATOR_MANIFEST"; then
    echo -e "${GREEN}[PASS]${NC} pattern: Operator 라벨 존재"
    ((PASSED++))
else
    echo -e "${RED}[FAIL]${NC} pattern: Operator 라벨 없음"
    ((FAILED++))
fi

# 4.15 web-app에 podDeleteSelector annotation이 없는지 확인 (CRD로 대체)
echo ""
echo "4.15 web-app에 podDeleteSelector annotation이 없는지 확인 (CRD로 대체)"
if ! grep -q 'k8spatterns.com/podDeleteSelector' "$WEBAPP_MANIFEST"; then
    echo -e "${GREEN}[PASS]${NC} web-app에 podDeleteSelector annotation 없음 (CRD로 대체됨)"
    ((PASSED++))
else
    echo -e "${RED}[FAIL]${NC} web-app에 podDeleteSelector annotation이 아직 존재 (CRD로 대체해야 함)"
    ((FAILED++))
fi

# 4.16 ConfigWatcher 샘플 CR 확인
echo ""
echo "4.16 ConfigWatcher 샘플 CR 확인"
if grep -q 'kind: ConfigWatcher' "$SAMPLE_MANIFEST"; then
    echo -e "${GREEN}[PASS]${NC} ConfigWatcher CR 샘플 존재"
    ((PASSED++))
else
    echo -e "${RED}[FAIL]${NC} ConfigWatcher CR 샘플 없음"
    ((FAILED++))
fi

# 4.17 샘플 CR의 configMap 필드 확인
echo ""
echo "4.17 샘플 CR의 configMap 필드 확인 (webapp-config)"
if grep -q 'configMap: webapp-config' "$SAMPLE_MANIFEST"; then
    echo -e "${GREEN}[PASS]${NC} 샘플 CR에 configMap: webapp-config 설정"
    ((PASSED++))
else
    echo -e "${RED}[FAIL]${NC} 샘플 CR의 configMap 설정이 올바르지 않음"
    ((FAILED++))
fi

# 4.18 샘플 CR의 podSelector 확인
echo ""
echo "4.18 샘플 CR의 podSelector 확인 (app: webapp)"
if grep -q 'app: webapp' "$SAMPLE_MANIFEST"; then
    echo -e "${GREEN}[PASS]${NC} 샘플 CR에 podSelector app=webapp 설정"
    ((PASSED++))
else
    echo -e "${RED}[FAIL]${NC} 샘플 CR의 podSelector가 올바르지 않음"
    ((FAILED++))
fi

echo ""
echo "========================================"
echo "결과: ${PASSED} 통과, ${FAILED} 실패"
echo "========================================"

if [ $FAILED -gt 0 ]; then
    exit 1
fi
