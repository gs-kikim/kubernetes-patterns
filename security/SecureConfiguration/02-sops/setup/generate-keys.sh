#!/bin/bash
# age 키 생성 스크립트

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KEYS_DIR="$SCRIPT_DIR/../keys"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

print_step() { echo -e "${YELLOW}[STEP]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }

echo "=========================================="
echo "age 암호화 키 생성"
echo "=========================================="
echo ""

mkdir -p "$KEYS_DIR"

if [[ -f "$KEYS_DIR/age.agekey" ]]; then
    echo "기존 키가 존재합니다: $KEYS_DIR/age.agekey"
    AGE_PUBLIC_KEY=$(grep "public key:" "$KEYS_DIR/age.agekey" | cut -d: -f2 | tr -d ' ')
    echo "공개키: $AGE_PUBLIC_KEY"
else
    print_step "새 age 키 쌍 생성"
    age-keygen -o "$KEYS_DIR/age.agekey"

    AGE_PUBLIC_KEY=$(grep "public key:" "$KEYS_DIR/age.agekey" | cut -d: -f2 | tr -d ' ')

    print_success "키 생성 완료!"
    echo "키 파일: $KEYS_DIR/age.agekey"
    echo "공개키: $AGE_PUBLIC_KEY"
fi

# .sops.yaml 생성
print_step ".sops.yaml 설정 파일 생성"
cat > "$SCRIPT_DIR/../.sops.yaml" <<EOF
creation_rules:
  - path_regex: .*\.enc\.yaml$
    encrypted_regex: ^(data|stringData)$
    age: $AGE_PUBLIC_KEY
EOF

echo ""
print_success "설정 완료!"
echo ""
echo "중요: keys/ 디렉토리는 .gitignore에 추가하세요!"
echo "  echo 'security/SecureConfiguration/02-sops/keys/' >> .gitignore"
