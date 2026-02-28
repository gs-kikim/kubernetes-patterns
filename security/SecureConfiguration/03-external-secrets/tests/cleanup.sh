#!/bin/bash
# External Secrets 테스트 리소스 정리

NAMESPACE="eso-test"

echo "External Secrets 테스트 리소스 정리 중..."

kubectl delete namespace $NAMESPACE --ignore-not-found=true

echo "정리 완료!"
