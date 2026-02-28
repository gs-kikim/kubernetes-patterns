#!/bin/bash
# CLI 도구 설치 스크립트

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

print_step() { echo -e "${YELLOW}[STEP]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }

echo "=========================================="
echo "Secure Configuration 도구 설치"
echo "=========================================="
echo ""

# Homebrew 확인
if ! command -v brew &> /dev/null; then
    echo "Homebrew가 설치되어 있지 않습니다. 먼저 Homebrew를 설치해주세요."
    exit 1
fi

# Helm 설치
print_step "Helm 설치"
if command -v helm &> /dev/null; then
    echo "  이미 설치됨: $(helm version --short)"
else
    brew install helm
    print_success "Helm 설치 완료"
fi

# sops 설치
print_step "sops 설치"
if command -v sops &> /dev/null; then
    echo "  이미 설치됨: sops $(sops --version 2>&1 | head -1)"
else
    brew install sops
    print_success "sops 설치 완료"
fi

# age 설치
print_step "age 설치"
if command -v age &> /dev/null; then
    echo "  이미 설치됨: $(age --version)"
else
    brew install age
    print_success "age 설치 완료"
fi

# kubeseal 설치
print_step "kubeseal 설치"
if command -v kubeseal &> /dev/null; then
    echo "  이미 설치됨: $(kubeseal --version)"
else
    brew install kubeseal
    print_success "kubeseal 설치 완료"
fi

# vault 설치
print_step "HashiCorp Vault 설치"
if command -v vault &> /dev/null; then
    echo "  이미 설치됨: $(vault version)"
else
    brew tap hashicorp/tap
    brew install hashicorp/tap/vault
    print_success "Vault 설치 완료"
fi

echo ""
echo "=========================================="
echo "모든 도구 설치 완료!"
echo "=========================================="
