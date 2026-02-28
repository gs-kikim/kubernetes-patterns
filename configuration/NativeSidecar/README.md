# Native Sidecar Containers Pattern

**Status**: GA since Kubernetes 1.33

This example demonstrates native sidecar containers using `restartPolicy: Always` on init containers.

## Key Features

1. **Sidecar starts before main container**
2. **Sidecar terminates after main container**
3. **Doesn't block Job completion**
4. **Supports all probe types**

## Files

- `sidecar-pod.yaml` - Pod with config-refreshing sidecar
- `sidecar-job.yaml` - Job demonstrating sidecar doesn't block completion
- `tests/test-sidecar.sh` - Test script

## Quick Start

```bash
# Deploy pod with sidecar
kubectl apply -f sidecar-pod.yaml

# Verify sidecar started first
kubectl logs webapp-sidecar -c config-sidecar --tail=20

# Deploy job to verify completion behavior
kubectl apply -f sidecar-job.yaml
kubectl wait --for=condition=complete --timeout=60s job/data-processor
```

## Test

```bash
./tests/test-sidecar.sh
```
