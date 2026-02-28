# Configuration Resource Pattern

## Overview

The **Configuration Resource** pattern demonstrates how to use Kubernetes' native ConfigMap and Secret resources to manage application configuration. This pattern provides more flexibility than environment variables alone, supporting both key-value pairs and entire configuration files.

## Pattern Description

ConfigMaps and Secrets are first-class Kubernetes resources designed for configuration management:
- **ConfigMap**: For non-sensitive configuration data
- **Secret**: For sensitive information (base64 encoded)

Both can be consumed as:
1. Environment variables
2. Volume-mounted files

## Directory Structure

```
ConfigurationResource/
├── manifests/
│   ├── configmap.yaml              # Basic ConfigMap
│   ├── configmap-mutable.yaml      # Mutable ConfigMap for hot reload
│   ├── configmap-immutable.yaml    # Immutable ConfigMap (v1.21+)
│   ├── pod.yaml                    # Pod using ConfigMap
│   ├── pod-mutable.yaml            # Pod for hot reload testing
│   └── service.yaml                # Service exposure
├── tests/
│   ├── test-basic.sh               # Basic ConfigMap usage test
│   ├── test-hot-reload.sh          # Hot reload behavior test
│   └── test-immutable.sh           # Immutable ConfigMap test
└── README.md                       # This file
```

## Quick Start

### Basic Usage

```bash
# Create ConfigMap
kubectl apply -f manifests/configmap.yaml

# Deploy Pod
kubectl apply -f manifests/pod.yaml

# Verify configuration
kubectl exec random-generator -- env | grep CONFIG_
kubectl exec random-generator -- cat /config/app/random-generator.properties
```

### Hot Reload Test

```bash
# Run the hot reload test
./tests/test-hot-reload.sh
```

### Immutable ConfigMap Test

```bash
# Run the immutable ConfigMap test
./tests/test-immutable.sh
```

## ConfigMap Usage Methods

### Method 1: Individual Environment Variable

```yaml
env:
- name: PATTERN
  valueFrom:
    configMapKeyRef:
      name: random-generator-config
      key: PATTERN
```

**Result**: Single environment variable from specific ConfigMap key

**Use case**: When you need only a few specific values

### Method 2: Bulk Import with Prefix

```yaml
envFrom:
- configMapRef:
    name: random-generator-config
  prefix: CONFIG_
```

**Result**: All ConfigMap keys become environment variables with prefix
- `PATTERN` → `CONFIG_PATTERN`
- `SEED` → `CONFIG_SEED`
- `application.properties` → `CONFIG_application.properties`

**Use case**: Importing entire ConfigMap as environment variables

### Method 3: Volume Mount (Specific Files)

```yaml
volumes:
- name: config-volume
  configMap:
    name: random-generator-config
    items:
    - key: application.properties
      path: app/random-generator.properties
      mode: 0400
volumeMounts:
- name: config-volume
  mountPath: /config
```

**Result**: File at `/config/app/random-generator.properties` with mode 0400

**Use case**: Mount specific ConfigMap keys as files with custom paths/permissions

### Method 4: Volume Mount (All Keys)

```yaml
volumes:
- name: config-volume
  configMap:
    name: random-generator-config
volumeMounts:
- name: config-volume
  mountPath: /config
```

**Result**: All ConfigMap keys become files in `/config/`

**Use case**: Mount entire ConfigMap as a directory

## Hot Reload Behavior

### Environment Variables: NO Hot Reload ❌

Environment variables are set at Pod creation and **never update** when ConfigMap changes.

```bash
# Update ConfigMap
kubectl patch configmap app-config -p '{"data":{"VERSION":"2.0"}}'

# Environment variable stays at old value
kubectl exec pod-name -- env | grep VERSION
# VERSION=1.0  (unchanged)
```

**Solution**: Restart the Pod or use volume mounts

### Volume Mounts: Hot Reload ✅

Files mounted from ConfigMaps **automatically update** when ConfigMap changes.

**Propagation time**: 60-90 seconds (kubelet sync period)

```bash
# Update ConfigMap
kubectl patch configmap app-config -p '{"data":{"config.yaml":"new content"}}'

# File updates automatically after ~60 seconds
kubectl exec pod-name -- cat /config/config.yaml
# Shows new content after propagation
```

**How it works**:
1. Kubelet watches ConfigMaps used by Pods
2. Sync period: ~60 seconds (configurable with `--sync-frequency`)
3. Updates are atomic via symlinks:
   ```
   /config/config.yaml -> ..data/config.yaml
   ..data -> ..2025_12_20_10_11_45.842141524
   ```
4. Application must detect file changes (inotify, polling, etc.)

**Test Results**:
- ✅ File content updates in ~60 seconds
- ✅ Atomic updates via symlinks
- ⚠️ Application must implement file watching
- ⚠️ Environment variables never update

## Immutable ConfigMaps (Kubernetes 1.21+)

### What is Immutable?

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config
data:
  VERSION: "1.0"
immutable: true  # Cannot be modified after creation
```

### Benefits

1. **Protection**: Prevents accidental updates
2. **Performance**: Kubelet doesn't watch for changes (reduces API server load)
3. **Safety**: No configuration drift
4. **Predictability**: Configuration is guaranteed to be stable

### Update Strategy

Immutable ConfigMaps cannot be modified. To update:

```bash
# 1. Create new ConfigMap with different name
kubectl apply -f app-config-v2.yaml

# 2. Update Deployment to use new ConfigMap
kubectl set env deployment/myapp --from=configmap/app-config-v2

# 3. Delete old ConfigMap after rollout
kubectl delete configmap app-config-v1
```

**Recommended naming**:
- Version suffix: `app-config-v1`, `app-config-v2`
- Date suffix: `app-config-20250120`
- Git hash suffix: `app-config-abc1234`

### Test Results

```bash
# Attempt to update immutable ConfigMap
kubectl patch configmap immutable-config -p '{"data":{"KEY":"new-value"}}'

# Error (expected):
# The ConfigMap "immutable-config" is invalid:
# data: Forbidden: field is immutable when `immutable` is set
```

✅ **Result**: Updates are correctly rejected

## Running Tests

### Test 1: Basic ConfigMap Usage

```bash
./tests/test-basic.sh
```

**Tests**:
- ✅ ConfigMap creation
- ✅ Individual environment variable reference
- ✅ Bulk import with prefix
- ✅ Volume mount with specific files
- ✅ File permissions (mode: 0400)

**Duration**: ~30 seconds

### Test 2: Hot Reload Behavior

```bash
./tests/test-hot-reload.sh
```

**Tests**:
- ✅ ConfigMap update propagation to volume mounts
- ✅ Environment variable immutability
- ✅ Propagation timing measurement (~60 seconds)

**Duration**: ~2 minutes

### Test 3: Immutable ConfigMaps

```bash
./tests/test-immutable.sh
```

**Tests**:
- ✅ Immutable flag enforcement
- ✅ Update rejection
- ✅ Comparison with mutable ConfigMaps

**Duration**: ~20 seconds

## Test Results Summary

See [../TEST_RESULTS.md](../TEST_RESULTS.md) for detailed results.

| Test | Status | Duration | Key Finding |
|------|--------|----------|-------------|
| Basic | ✅ PASS | ~30s | All ConfigMap usage methods work |
| Hot Reload | ✅ PASS | ~2m | Volume mounts update, env vars don't |
| Immutable | ✅ PASS | ~20s | Immutability correctly enforced |

## Best Practices

### ✅ DO

1. **Use ConfigMaps for non-sensitive data**
   ```yaml
   data:
     database.host: "localhost"
     log.level: "INFO"
   ```

2. **Use Secrets for sensitive data**
   ```yaml
   stringData:
     password: "secretpassword"
     api-key: "abc123"
   ```

3. **Use immutable ConfigMaps in production**
   ```yaml
   immutable: true
   ```

4. **Version your ConfigMaps**
   ```yaml
   metadata:
     name: app-config-v1  # or v2, v3, etc.
   ```

5. **Set file permissions for mounted configs**
   ```yaml
   items:
   - key: config.yaml
     path: config.yaml
     mode: 0400  # read-only for owner
   ```

6. **Use volume mounts for large configs or files**
   ```yaml
   volumeMounts:
   - name: config
     mountPath: /etc/app/config.yaml
     subPath: config.yaml
   ```

### ❌ DON'T

1. **Don't store passwords in ConfigMaps**
   - Use Secrets instead

2. **Don't exceed 1MB ConfigMap size**
   - Split into multiple ConfigMaps
   - Or use Immutable Configuration pattern

3. **Don't rely on hot reload for critical updates**
   - 60-90 second delay is not guaranteed
   - Application must detect file changes

4. **Don't use mutable ConfigMaps in production**
   - Configuration drift risk
   - Use immutable ConfigMaps with versioning

## Configuration File Examples

### Application Properties

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config
data:
  application.properties: |
    server.port=8080
    database.host=postgres.default.svc.cluster.local
    database.port=5432
    log.level=INFO
    cache.ttl=3600
```

### YAML Configuration

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config
data:
  config.yaml: |
    server:
      port: 8080
      host: 0.0.0.0
    database:
      host: postgres.default.svc.cluster.local
      port: 5432
    logging:
      level: INFO
```

### JSON Configuration

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config
data:
  config.json: |
    {
      "server": {
        "port": 8080,
        "host": "0.0.0.0"
      },
      "database": {
        "host": "postgres.default.svc.cluster.local",
        "port": 5432
      }
    }
```

### Nginx Configuration

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: nginx-config
data:
  nginx.conf: |
    server {
        listen 80;
        server_name localhost;

        location / {
            root /usr/share/nginx/html;
            index index.html;
        }

        location /api {
            proxy_pass http://backend:8080;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
        }
    }
```

## Advanced Patterns

### 1. ConfigMap with Kustomize

```yaml
# kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

configMapGenerator:
- name: app-config
  files:
  - application.properties
  options:
    disableNameSuffixHash: false  # Adds hash suffix for versioning
```

**Result**: `app-config-abc123` with automatic versioning

### 2. External Secrets Operator

```yaml
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: database-credentials
spec:
  refreshInterval: 1h
  secretStoreRef:
    kind: ClusterSecretStore
    name: aws-secrets-manager
  target:
    name: db-credentials
  data:
  - secretKey: password
    remoteRef:
      key: prod/database/password
```

### 3. Reloader for Auto-Restart

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: myapp
  annotations:
    reloader.stakater.com/auto: "true"  # Auto-restart on ConfigMap change
spec:
  template:
    spec:
      containers:
      - name: app
        envFrom:
        - configMapRef:
            name: app-config
```

## Troubleshooting

### ConfigMap not found

```bash
# List ConfigMaps
kubectl get configmaps

# Describe ConfigMap
kubectl describe configmap random-generator-config
```

### File not updating

```bash
# Check ConfigMap
kubectl get configmap app-config -o yaml

# Check if ConfigMap is immutable
kubectl get configmap app-config -o jsonpath='{.immutable}'

# Wait for propagation (up to 90 seconds)
sleep 90
kubectl exec pod-name -- cat /config/file.yaml
```

### Permission denied

```bash
# Check file permissions
kubectl exec pod-name -- ls -la /config/

# Update mode in ConfigMap volume
# (mode: 0644 for read-write, 0400 for read-only)
```

## Security Considerations

1. **Use Secrets for sensitive data**
   - Passwords, API keys, certificates
   - Base64 is encoding, not encryption

2. **Enable RBAC**
   ```yaml
   apiVersion: rbac.authorization.k8s.io/v1
   kind: Role
   rules:
   - resources: ["configmaps"]
     verbs: ["get", "list"]
   - resources: ["secrets"]
     verbs: ["get"]  # Read-only
   ```

3. **Encrypt Secrets at rest**
   - Enable etcd encryption
   - Use cloud provider encryption

4. **Use External Secrets**
   - HashiCorp Vault
   - AWS Secrets Manager
   - Azure Key Vault

5. **Audit access**
   - Enable audit logging
   - Monitor ConfigMap/Secret access

## Related Patterns

- **EnvVar Configuration** (Chapter 19) - Environment variable based configuration
- **Immutable Configuration** (Chapter 21) - Large configs in separate containers
- **Configuration Template** (Chapter 22) - Template-based configuration generation

## References

- [Kubernetes Documentation - ConfigMap](https://kubernetes.io/docs/concepts/configuration/configmap/)
- [Kubernetes Documentation - Secrets](https://kubernetes.io/docs/concepts/configuration/secret/)
- [Kubernetes Documentation - Configure Pod ConfigMap](https://kubernetes.io/docs/tasks/configure-pod-container/configure-pod-configmap/)
- [Kubernetes Enhancement - Immutable ConfigMaps and Secrets](https://github.com/kubernetes/enhancements/tree/master/keps/sig-storage/1412-immutable-secrets-and-configmaps)
- [External Secrets Operator](https://external-secrets.io/)
- [Reloader](https://github.com/stakater/Reloader)
- [Kubernetes Patterns Book - Chapter 20](https://www.oreilly.com/library/view/kubernetes-patterns/9781492050278/)
