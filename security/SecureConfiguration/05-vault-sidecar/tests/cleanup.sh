#!/bin/bash
# Vault Sidecar 테스트 리소스 정리

NAMESPACE="vault-sidecar-test"

echo "Vault Sidecar 테스트 리소스 정리 중..."

kubectl delete namespace $NAMESPACE --ignore-not-found=true

echo "정리 완료!"
