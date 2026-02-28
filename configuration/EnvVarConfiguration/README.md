# EnvVar Configuration Pattern

## Overview

The **EnvVar Configuration** pattern demonstrates how to externalize application configuration using environment variables in Kubernetes. This is the simplest and most universal configuration method, supported by all operating systems and programming languages.

## Pattern Description

Environment variables provide a platform-agnostic way to configure applications at runtime. Kubernetes enhances this basic mechanism with:
- ConfigMap references
- Secret references
- Downward API for Pod metadata
- Dependent variable expansion

## Directory Structure

```
EnvVarConfiguration/
├── manifests/
│   ├── configmap.yaml      # ConfigMap with configuration data
│   ├── secret.yaml         # Secret with sensitive data
│   ├── pod.yaml            # Pod using various env var methods
│   └── service.yaml        # Service to expose the Pod
├── tests/
│   └── test-envvar.sh      # Automated test script
└── README.md               # This file
```

## Quick Start

### Prerequisites
- Kubernetes cluster (minikube, kind, or cloud provider)
- kubectl configured to access your cluster

### Deploy

```bash
# Create ConfigMap
kubectl apply -f manifests/configmap.yaml

# Create Secret
kubectl apply -f manifests/secret.yaml

# Deploy Pod
kubectl apply -f manifests/pod.yaml

# Expose Service
kubectl apply -f manifests/service.yaml
```

### Verify

```bash
# Check Pod status
kubectl get pod random-generator

# View all environment variables
kubectl exec random-generator -- env | sort

# Test specific variables
kubectl exec random-generator -- env | grep -E "(PATTERN|SEED|IP|MY_URL)"

# Access the service
MINIKUBE_IP=$(minikube ip)
curl http://${MINIKUBE_IP}:30080/info
```

### Cleanup

```bash
kubectl delete -f manifests/
```

## Environment Variable Methods

### 1. Direct Literal Values

```yaml
env:
- name: LOG_FILE
  value: /tmp/random.log
- name: PORT
  value: "8181"
```

**Use case**: Simple, static configuration values

### 2. ConfigMap References

```yaml
env:
- name: PATTERN
  valueFrom:
    configMapKeyRef:
      name: random-generator-config
      key: PATTERN
```

**Use case**: Non-sensitive configuration data

### 3. Secret References

```yaml
env:
- name: SEED
  valueFrom:
    secretKeyRef:
      name: random-generator-secret
      key: seed
```

**Use case**: Sensitive data (passwords, API keys, tokens)

### 4. Downward API

```yaml
env:
- name: IP
  valueFrom:
    fieldRef:
      fieldPath: status.podIP
```

**Use case**: Pod metadata (name, IP, namespace, labels)

**Available fields**:
- `metadata.name` - Pod name
- `metadata.namespace` - Pod namespace
- `status.podIP` - Pod IP address
- `spec.serviceAccountName` - Service account name
- `metadata.labels['<KEY>']` - Specific label
- `metadata.annotations['<KEY>']` - Specific annotation

### 5. Dependent Variables

```yaml
env:
- name: PORT
  value: "8181"
- name: IP
  valueFrom:
    fieldRef:
      fieldPath: status.podIP
- name: MY_URL
  value: "https://$(IP):$(PORT)/api"
```

**Use case**: Composing URLs or paths from multiple variables

**Note**: Variable expansion happens during Pod creation. Nested expansion like `$(VAR1)/$(VAR2)` has limitations.

### 6. Bulk Import with Prefix

```yaml
envFrom:
- configMapRef:
    name: random-generator-config
  prefix: RANDOM_
```

**Result**: All ConfigMap keys become environment variables with `RANDOM_` prefix
- `PATTERN` → `RANDOM_PATTERN`
- `EXTRA_OPTIONS` → `RANDOM_EXTRA_OPTIONS`

**Use case**: Importing multiple configuration values at once, avoiding name collisions

## Running Tests

```bash
# Make script executable
chmod +x tests/test-envvar.sh

# Run test
./tests/test-envvar.sh
```

### Test Coverage

The test script validates:
- ✅ Direct literal environment variables
- ✅ ConfigMap references
- ✅ Secret references
- ✅ Downward API (Pod IP)
- ✅ Dependent variables
- ✅ Bulk import with prefix
- ✅ Invalid environment variable name handling

## Test Results

See [../TEST_RESULTS.md](../TEST_RESULTS.md) for detailed test results.

**Summary**:
- **Status**: ✅ PASS
- **Duration**: ~30 seconds
- **Key Finding**: All environment variable injection methods work correctly

## Key Learnings

### ✅ Advantages
1. **Universal**: Works across all platforms and languages
2. **Simple**: Easy to understand and implement
3. **Standard**: Follows 12-factor app methodology
4. **Flexible**: Multiple injection methods available

### ⚠️ Limitations
1. **No Hot Reload**: Changes require Pod restart
2. **Size Limit**: Not suitable for large configurations
3. **No Structure**: Flat key-value pairs only
4. **Visibility**: Visible in Pod spec and process list
5. **Limited Validation**: No schema validation

### 🔐 Security Considerations
1. Use **Secrets** for sensitive data, not ConfigMaps
2. Enable **RBAC** to control Secret access
3. Consider **External Secrets Operator** for vault integration
4. Avoid logging environment variables
5. Use **read-only** volumes when possible

## Best Practices

### DO ✅
- Use environment variables for small, simple configurations
- Use Secrets for sensitive data (passwords, tokens)
- Use meaningful variable names (uppercase with underscores)
- Use prefixes when importing ConfigMaps to avoid collisions
- Document all environment variables in your application

### DON'T ❌
- Store sensitive data in ConfigMaps
- Use environment variables for large configuration files
- Hardcode default values that should be configurable
- Use complex nested variable expansion
- Log environment variable values in production

## Common Patterns

### Database Connection

```yaml
env:
- name: DB_HOST
  valueFrom:
    configMapKeyRef:
      name: app-config
      key: database.host
- name: DB_PORT
  valueFrom:
    configMapKeyRef:
      name: app-config
      key: database.port
- name: DB_USER
  valueFrom:
    secretKeyRef:
      name: db-credentials
      key: username
- name: DB_PASSWORD
  valueFrom:
    secretKeyRef:
      name: db-credentials
      key: password
- name: DB_CONNECTION_STRING
  value: "postgresql://$(DB_USER):$(DB_PASSWORD)@$(DB_HOST):$(DB_PORT)/mydb"
```

### Feature Flags

```yaml
envFrom:
- configMapRef:
    name: feature-flags
  prefix: FEATURE_
# Results in: FEATURE_NEW_UI, FEATURE_BETA_API, etc.
```

### Service Discovery

```yaml
env:
- name: POD_IP
  valueFrom:
    fieldRef:
      fieldPath: status.podIP
- name: POD_NAME
  valueFrom:
    fieldRef:
      fieldPath: metadata.name
- name: NAMESPACE
  valueFrom:
    fieldRef:
      fieldPath: metadata.namespace
```

## Troubleshooting

### Environment variable not set

```bash
# Check if ConfigMap exists
kubectl get configmap random-generator-config

# Check if Secret exists
kubectl get secret random-generator-secret

# View ConfigMap data
kubectl get configmap random-generator-config -o yaml

# Check Pod events
kubectl describe pod random-generator
```

### Invalid environment variable names

Environment variables must match: `^[a-zA-Z_][a-zA-Z0-9_]*$`

Invalid characters (like dots) in ConfigMap keys may be accepted with prefixes but could cause issues in some languages.

### Dependent variables not expanding

- Ensure referenced variables are defined **before** dependent variables
- Variables are expanded at Pod creation time, not runtime
- Complex expansions may not work as expected

## Related Patterns

- **Configuration Resource** (Chapter 20) - ConfigMap and Secret as volumes
- **Immutable Configuration** (Chapter 21) - Larger configs in separate containers
- **Configuration Template** (Chapter 22) - Template-based configuration generation

## References

- [Kubernetes Documentation - Environment Variables](https://kubernetes.io/docs/tasks/inject-data-application/define-environment-variable-container/)
- [Kubernetes Documentation - ConfigMap](https://kubernetes.io/docs/concepts/configuration/configmap/)
- [Kubernetes Documentation - Secrets](https://kubernetes.io/docs/concepts/configuration/secret/)
- [Kubernetes Documentation - Downward API](https://kubernetes.io/docs/concepts/workloads/pods/downward-api/)
- [Twelve-Factor App - Config](https://12factor.net/config)
- [Kubernetes Patterns Book - Chapter 19](https://www.oreilly.com/library/view/kubernetes-patterns/9781492050278/)
