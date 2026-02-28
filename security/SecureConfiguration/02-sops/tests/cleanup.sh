#!/bin/bash
# sops 테스트 리소스 정리

NAMESPACE="sops-test"

echo "sops 테스트 리소스 정리 중..."

kubectl delete namespace $NAMESPACE --ignore-not-found=true
rm -f /tmp/encrypted-secret.enc.yaml /tmp/decrypted-secret.yaml

echo "정리 완료!"
