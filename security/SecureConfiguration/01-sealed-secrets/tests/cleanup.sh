#!/bin/bash
# Sealed Secrets 테스트 리소스 정리

NAMESPACE="sealed-secrets-test"

echo "Sealed Secrets 테스트 리소스 정리 중..."

kubectl delete namespace $NAMESPACE --ignore-not-found=true
rm -f /tmp/sealed-secret.yaml

echo "정리 완료!"
