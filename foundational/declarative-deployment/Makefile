# Makefile for Declarative Deployment Examples

.PHONY: help setup install-flux install-flagger test-all test-rolling test-blue-green test-canary clean lint lint-fix

help: ## Show this help message
	@echo "Usage: make [target]"
	@echo ""
	@echo "Available targets:"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2}'

setup: ## Setup Minikube environment
	@echo "Setting up Minikube..."
	@chmod +x scripts/*.sh
	@./scripts/setup-minikube.sh

install-flux: ## Install FluxCD
	@echo "Installing FluxCD..."
	@./scripts/install-fluxcd.sh

install-flagger: ## Install Flagger for canary deployments
	@echo "Installing Flagger..."
	@./scripts/install-flagger.sh

install: setup install-flux install-flagger ## Complete installation (Minikube + FluxCD + Flagger)

test-rolling: ## Test rolling update deployment
	@echo "Testing Rolling Update..."
	@./scripts/test-rolling-update.sh

test-blue-green: ## Test blue-green deployment
	@echo "Testing Blue-Green Deployment..."
	@./scripts/test-blue-green.sh

test-canary: ## Test canary deployment
	@echo "Testing Canary Deployment..."
	@./scripts/test-canary.sh

test-all: test-rolling test-blue-green test-canary ## Test all deployment strategies

monitor: ## Monitor all deployments
	@echo "Monitoring deployments..."
	@watch -n 2 'kubectl get pods -A | grep -E "rolling|blue-green|canary"'

logs-flux: ## Show FluxCD logs
	@kubectl -n flux-system logs -f deployment/source-controller

logs-flagger: ## Show Flagger logs
	@kubectl -n flagger-system logs -f deployment/flagger

status: ## Show status of all components
	@echo "=== Minikube Status ==="
	@minikube status || true
	@echo ""
	@echo "=== FluxCD Status ==="
	@flux check || true
	@echo ""
	@echo "=== Deployments ==="
	@kubectl get deployments -A | grep -E "rolling|blue-green|canary" || echo "No deployments found"
	@echo ""
	@echo "=== Services ==="
	@kubectl get services -A | grep -E "rolling|blue-green|canary" || echo "No services found"

lint: ## Run kube-linter on all Kubernetes manifests
	@echo "Running kube-linter..."
	@chmod +x scripts/lint-check.sh
	@./scripts/lint-check.sh

lint-fix: ## Auto-fix linting issues where possible
	@echo "Fixing YAML formatting..."
	@find apps -name "*.yaml" -type f -exec yamllint -d relaxed --fix {} \;
	@echo "Formatting shell scripts..."
	@find scripts -name "*.sh" -type f -exec shfmt -w {} \;
	@echo "Auto-fix completed. Run 'make lint' to check remaining issues."

validate: ## Validate all Kubernetes manifests
	@echo "Validating Kubernetes manifests..."
	@find apps -name "*.yaml" -type f -exec kubectl --dry-run=client apply -f {} \; 2>&1 | grep -v "created (dry run)" || true

clean: ## Clean up all deployments
	@echo "Cleaning up..."
	@./scripts/cleanup.sh

reset: clean install ## Reset everything and reinstall

dashboard: ## Open Kubernetes dashboard
	@minikube dashboard