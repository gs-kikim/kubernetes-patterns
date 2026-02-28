# Secure Configuration 패턴

쿠버네티스에서 민감한 설정 데이터를 안전하게 관리하는 5가지 솔루션을 테스트합니다.

## 테스트 대상 솔루션

| 솔루션 | 설명 | 디렉토리 |
|--------|------|----------|
| **Sealed Secrets** | Git에 안전하게 저장 가능한 암호화된 Secret | `01-sealed-secrets/` |
| **sops + age** | 클라이언트 측 암호화 도구 | `02-sops/` |
| **External Secrets Operator** | 외부 SMS 연동 | `03-external-secrets/` |
| **Secrets Store CSI Driver** | CSI 볼륨으로 Secret 마운트 | `04-secrets-store-csi/` |
| **Vault Sidecar Injector** | Vault Agent 자동 주입 | `05-vault-sidecar/` |

## 빠른 시작

### 1. 사전 요구사항

```bash
# CLI 도구 설치
bash 00-setup/00-install-tools.sh

# minikube 시작
bash 00-setup/01-start-minikube.sh
```

### 2. 전체 테스트 실행

```bash
bash scripts/test-all.sh
```

### 3. 개별 테스트 실행

```bash
# Sealed Secrets
bash 01-sealed-secrets/tests/test-seal-unseal.sh

# sops + age
bash 02-sops/tests/test-encrypt-decrypt.sh

# External Secrets Operator
bash 03-external-secrets/tests/test-fake-provider.sh

# Secrets Store CSI Driver (Vault 필요)
bash 00-setup/02-install-vault.sh
bash 04-secrets-store-csi/tests/test-volume-mount.sh

# Vault Sidecar Injector
bash 05-vault-sidecar/tests/test-sidecar-injection.sh
```

### 4. 정리

```bash
bash scripts/cleanup-all.sh
```

## 솔루션 비교

| 기능 | Sealed Secrets | sops | ESO | CSI Driver | Vault Sidecar |
|------|----------------|------|-----|------------|---------------|
| **GitOps 친화적** | O | O | O | X | X |
| **외부 SMS 연동** | X | X | O | O | O |
| **클러스터 내 Secret 저장** | O | O | O | X | X |
| **자동 Secret 로테이션** | X | X | O | O | O |
| **설치 복잡도** | 낮음 | 낮음 | 중간 | 높음 | 중간 |

## 사용 시나리오별 권장

1. **간단한 GitOps**: `sops + age` - 추가 인프라 없이 시작
2. **기존 클라우드 SMS 활용**: `External Secrets Operator`
3. **클러스터 내 Secret 저장 불가**: `CSI Driver` 또는 `Vault Sidecar`
4. **동적 Secret 필요**: `Vault Sidecar Injector`

## 참고 자료

- [Kubernetes Patterns - Chapter 25: Secure Configuration](https://www.oreilly.com/library/view/kubernetes-patterns-2nd/9781098131678/)
- [Sealed Secrets](https://github.com/bitnami-labs/sealed-secrets)
- [External Secrets Operator](https://external-secrets.io/)
- [sops](https://github.com/getsops/sops)
- [Secrets Store CSI Driver](https://secrets-store-csi-driver.sigs.k8s.io/)
- [Vault Sidecar Injector](https://developer.hashicorp.com/vault/docs/platform/k8s/injector)
