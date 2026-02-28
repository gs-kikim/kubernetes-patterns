#!/bin/bash
# 통합 테스트 스크립트

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEST_DIR="$SCRIPT_DIR/../7-integration"

echo "=========================================="
echo "통합 테스트 시작"
echo "=========================================="
echo ""

# Test 1: 프로덕션급 보안 설정
echo "[Test 1] 프로덕션급 보안 설정 테스트"
kubectl apply -f "$TEST_DIR/01-production-ready.yaml"
kubectl wait --for=condition=Ready pod/production-secure-app --timeout=60s

echo "→ 애플리케이션 헬스 체크..."
sleep 5
kubectl exec production-secure-app -- wget -q -O- http://localhost:8080 | head -20

echo ""
echo "→ 보안 설정 확인..."
echo "  - runAsNonRoot: $(kubectl get pod production-secure-app -o jsonpath='{.spec.securityContext.runAsNonRoot}')"
echo "  - seccompProfile: $(kubectl get pod production-secure-app -o jsonpath='{.spec.securityContext.seccompProfile.type}')"
echo "  - readOnlyRootFilesystem: $(kubectl get pod production-secure-app -o jsonpath='{.spec.containers[0].securityContext.readOnlyRootFilesystem}')"
echo "  - capabilities: $(kubectl get pod production-secure-app -o jsonpath='{.spec.containers[0].securityContext.capabilities.drop[0]}')"
echo ""

# Test 2: 레거시 앱 마이그레이션
echo "[Test 2] 레거시 앱 보안 마이그레이션 테스트"
kubectl apply -f "$TEST_DIR/02-legacy-migration.yaml"
kubectl wait --for=condition=Ready pod/legacy-app-secure --timeout=60s

echo "→ Init Container 로그 (권한 설정):"
kubectl logs legacy-app-secure -c setup-permissions

echo ""
echo "→ Application Container 로그 (non-root 실행):"
kubectl logs legacy-app-secure -c app
echo ""

# Test 3: 멀티 컨테이너 보안
echo "[Test 3] 멀티 컨테이너 Pod 보안 테스트"
kubectl apply -f "$TEST_DIR/03-multi-container.yaml"
kubectl wait --for=condition=Ready pod/multi-container-secure --timeout=60s

echo "→ 애플리케이션 요청 생성 중..."
sleep 3
kubectl exec multi-container-secure -c app -- wget -q -O- http://localhost:8080 > /dev/null
sleep 2

echo ""
echo "→ 로그 수집기 Sidecar 로그:"
kubectl logs multi-container-secure -c log-collector --tail=5

echo ""
echo "→ 각 컨테이너의 사용자 ID 확인:"
echo "  App Container:"
kubectl exec multi-container-secure -c app -- id
echo "  Log Collector:"
kubectl exec multi-container-secure -c log-collector -- id
echo ""

echo "=========================================="
echo "통합 테스트 완료"
echo "=========================================="
echo ""
echo "정리하려면: kubectl delete -f $TEST_DIR/"
