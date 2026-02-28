# Configuration Template Pattern

This example demonstrates the Configuration Template pattern using gomplate to dynamically process configuration files at pod startup.

## Overview

The Configuration Template pattern allows you to:
- Template large configuration files with dynamic values
- Separate configuration data (ConfigMap) from configuration structure (template)
- Support multiple environments (dev, prod) with the same template

## Architecture

```
┌─────────────────────────────────────┐
│         Pod                         │
│  ┌───────────────────────────────┐  │
│  │ Init Container (gomplate)     │  │
│  │ - Reads ConfigMap             │  │
│  │ - Processes template          │  │
│  │ - Writes final config         │  │
│  └───────────────────────────────┘  │
│           ↓                         │
│  ┌───────────────────────────────┐  │
│  │ Main Container (nginx)        │  │
│  │ - Uses processed config       │  │
│  └───────────────────────────────┘  │
└─────────────────────────────────────┘
```

## Files

- `dev/configmap-dev.yaml` - Development environment configuration
- `prod/configmap-prod.yaml` - Production environment configuration
- `deployment.yaml` - Deployment with init container
- `service.yaml` - Service definition
- `init-container/Dockerfile` - Custom gomplate image (optional)
- `tests/test-basic.sh` - Basic functionality test
- `tests/test-switch-env.sh` - Environment switching test

## Quick Start

### 1. Deploy with Development Configuration

```bash
kubectl apply -f dev/configmap-dev.yaml
kubectl apply -f deployment.yaml
kubectl apply -f service.yaml
```

### 2. Verify Configuration

```bash
# Check logs for environment indicator
kubectl logs -l app=webapp -c webapp

# Check processed configuration
kubectl exec -it $(kubectl get pod -l app=webapp -o jsonpath='{.items[0].metadata.name}') -- cat /usr/share/nginx/html/index.html
```

### 3. Switch to Production Configuration

```bash
kubectl delete configmap webapp-config
kubectl apply -f prod/configmap-prod.yaml
kubectl rollout restart deployment webapp
```

## Run Tests

```bash
# Basic functionality test
./tests/test-basic.sh

# Environment switching test
./tests/test-switch-env.sh
```

## Key Features Demonstrated

1. **Template Processing**: gomplate reads from ConfigMap and processes templates
2. **Init Container Pattern**: Configuration is prepared before main container starts
3. **Environment Separation**: Same template, different configurations
4. **Shared Volume**: emptyDir volume shares processed config between containers

## Cleanup

```bash
kubectl delete -f service.yaml
kubectl delete -f deployment.yaml
kubectl delete configmap webapp-config
```
