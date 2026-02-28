#!/bin/bash
# sops + age 테스트 스크립트

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$SCRIPT_DIR/.."
KEYS_DIR="$BASE_DIR/keys"
NAMESPACE="sops-test"

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

print_step() { echo -e "${YELLOW}[STEP]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }

echo "=========================================="
echo "sops + age 테스트"
echo "=========================================="
echo ""

# 키 생성 (없으면)
print_step "1. age 키 확인/생성"
if [[ ! -f "$KEYS_DIR/age.agekey" ]]; then
    bash "$BASE_DIR/setup/generate-keys.sh"
fi

AGE_PUBLIC_KEY=$(grep "public key:" "$KEYS_DIR/age.agekey" | cut -d: -f2 | tr -d ' ')
echo "  공개키: $AGE_PUBLIC_KEY"

# 평문 Secret 확인
print_step "2. 평문 Secret 확인"
echo "  원본 파일:"
cat "$BASE_DIR/manifests/01-plain-secret.yaml"

# Secret 암호화
print_step "3. Secret 암호화 (stringData만 암호화)"
export SOPS_AGE_RECIPIENTS="$AGE_PUBLIC_KEY"
sops --encrypt \
    --encrypted-regex '^(data|stringData)$' \
    "$BASE_DIR/manifests/01-plain-secret.yaml" > /tmp/encrypted-secret.enc.yaml

echo "  암호화된 파일:"
cat /tmp/encrypted-secret.enc.yaml

# 암호화 확인
print_step "4. 암호화 상태 확인"
if grep -q "ENC\[AES256_GCM" /tmp/encrypted-secret.enc.yaml; then
    print_success "stringData가 암호화됨!"
else
    print_error "암호화되지 않았습니다"
    exit 1
fi

# metadata가 평문인지 확인
if grep -q "name: sops-test-secret" /tmp/encrypted-secret.enc.yaml; then
    print_success "metadata는 평문으로 유지됨 (Git에서 검색 가능)"
else
    print_error "metadata도 암호화됨 (예상치 못한 동작)"
fi

# Secret 복호화
print_step "5. Secret 복호화"
export SOPS_AGE_KEY_FILE="$KEYS_DIR/age.agekey"
sops --decrypt /tmp/encrypted-secret.enc.yaml > /tmp/decrypted-secret.yaml

echo "  복호화된 파일:"
cat /tmp/decrypted-secret.yaml

# 복호화 값 검증
print_step "6. 복호화 값 검증"
DECRYPTED_USERNAME=$(grep "username:" /tmp/decrypted-secret.yaml | awk '{print $2}')
if [[ "$DECRYPTED_USERNAME" == "admin" ]]; then
    print_success "복호화된 값이 원본과 일치!"
else
    print_error "복호화 실패: $DECRYPTED_USERNAME"
    exit 1
fi

# 클러스터에 적용
print_step "7. 클러스터에 적용"
kubectl create namespace $NAMESPACE --dry-run=client -o yaml | kubectl apply -f -
sops --decrypt /tmp/encrypted-secret.enc.yaml | kubectl apply -f -

# Secret 확인
print_step "8. 클러스터에서 Secret 확인"
kubectl get secret sops-test-secret -n $NAMESPACE

CLUSTER_USERNAME=$(kubectl get secret sops-test-secret -n $NAMESPACE -o jsonpath='{.data.username}' | base64 -d)
if [[ "$CLUSTER_USERNAME" == "admin" ]]; then
    print_success "클러스터에 Secret이 정상 적용됨!"
else
    print_error "클러스터 Secret 값이 다릅니다: $CLUSTER_USERNAME"
    exit 1
fi

# Pod에서 테스트
print_step "9. Pod에서 Secret 사용 테스트"
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: sops-test-pod
  namespace: $NAMESPACE
spec:
  restartPolicy: Never
  containers:
    - name: test
      image: busybox:1.36
      command: ["sh", "-c"]
      args:
        - |
          echo "=== sops Secret 값 확인 ==="
          echo "Username: \$USERNAME"
          echo "API Key 앞 4자리: \${API_KEY:0:4}..."
          echo "=== 테스트 완료 ==="
          sleep 5
      env:
        - name: USERNAME
          valueFrom:
            secretKeyRef:
              name: sops-test-secret
              key: username
        - name: API_KEY
          valueFrom:
            secretKeyRef:
              name: sops-test-secret
              key: api-key
EOF

kubectl wait --for=condition=Ready pod/sops-test-pod -n $NAMESPACE --timeout=60s || true
sleep 3
echo "  Pod 로그:"
kubectl logs sops-test-pod -n $NAMESPACE || true

# 암호화된 파일 저장
print_step "10. 암호화된 파일 저장"
cp /tmp/encrypted-secret.enc.yaml "$BASE_DIR/manifests/02-encrypted-secret.enc.yaml"
echo "  저장 위치: $BASE_DIR/manifests/02-encrypted-secret.enc.yaml"
echo "  이 파일은 Git에 안전하게 커밋할 수 있습니다!"

echo ""
echo "=========================================="
print_success "sops + age 테스트 완료!"
echo "=========================================="
echo ""
echo "요약:"
echo "  - age 공개키로 Secret 암호화"
echo "  - metadata는 평문 유지 (Git 검색 가능)"
echo "  - 개인키로 복호화 후 kubectl apply"
echo "  - 암호화된 파일은 Git에 안전하게 저장 가능"
echo ""
echo "주의: 개인키 ($KEYS_DIR/age.agekey)는 절대 Git에 커밋하지 마세요!"
