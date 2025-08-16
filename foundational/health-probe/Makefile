# Makefile for Health Probe Pattern Tests

NAMESPACE ?= health-probe-test
MANIFEST_DIR = ./manifests
SCRIPT_DIR = ./scripts

.PHONY: help
help:
	@echo "Kubernetes Health Probe Pattern - Test Commands"
	@echo ""
	@echo "Usage: make [target]"
	@echo ""
	@echo "Targets:"
	@echo "  all           - Run all tests"
	@echo "  liveness      - Test liveness probes"
	@echo "  readiness     - Test readiness probes"
	@echo "  startup       - Test startup probe"
	@echo "  combined      - Test combined probes"
	@echo "  gate          - Test readiness gate"
	@echo "  monitor       - Monitor probe events"
	@echo "  simulator     - Run interactive probe simulator"
	@echo "  chaos         - Run chaos testing (5 minutes)"
	@echo "  apply-all     - Apply all manifests"
	@echo "  delete-all    - Delete all test resources"
	@echo "  clean         - Clean up all resources"
	@echo "  status        - Show current status of all pods"
	@echo "  events        - Show recent probe-related events"
	@echo "  logs          - Show logs from all test pods"

.PHONY: all
all:
	@$(SCRIPT_DIR)/test-health-probes.sh all

.PHONY: liveness
liveness:
	@$(SCRIPT_DIR)/test-health-probes.sh liveness

.PHONY: readiness
readiness:
	@$(SCRIPT_DIR)/test-health-probes.sh readiness

.PHONY: startup
startup:
	@$(SCRIPT_DIR)/test-health-probes.sh startup

.PHONY: combined
combined:
	@$(SCRIPT_DIR)/test-health-probes.sh combined

.PHONY: gate
gate:
	@$(SCRIPT_DIR)/test-health-probes.sh gate

.PHONY: monitor
monitor:
	@$(SCRIPT_DIR)/test-health-probes.sh monitor

.PHONY: simulator
simulator:
	@$(SCRIPT_DIR)/probe-simulator.sh

.PHONY: chaos
chaos:
	@echo "Starting 5-minute chaos test..."
	@bash -c "echo '5' | $(SCRIPT_DIR)/probe-simulator.sh"

.PHONY: apply-all
apply-all:
	@echo "Applying all manifests..."
	@kubectl apply -f $(MANIFEST_DIR)/ -n $(NAMESPACE)

.PHONY: delete-all
delete-all:
	@echo "Deleting all test resources..."
	@kubectl delete -f $(MANIFEST_DIR)/ -n $(NAMESPACE) --ignore-not-found=true

.PHONY: clean
clean: delete-all
	@echo "Cleanup complete"

.PHONY: status
status:
	@echo "Current pod status:"
	@kubectl get pods -n $(NAMESPACE) -l 'test' -o wide
	@echo ""
	@echo "Service endpoints:"
	@kubectl get endpoints -n $(NAMESPACE)

.PHONY: events
events:
	@echo "Recent probe-related events:"
	@kubectl get events -n $(NAMESPACE) --sort-by='.lastTimestamp' | grep -E "(probe|Liveness|Readiness|Startup|Unhealthy)" | tail -20

.PHONY: logs
logs:
	@echo "Fetching logs from test pods..."
	@for pod in $$(kubectl get pods -n $(NAMESPACE) -l 'test' -o name); do \
		echo "===== Logs from $$pod ====="; \
		kubectl logs -n $(NAMESPACE) $$pod --tail=20; \
		echo ""; \
	done

.PHONY: test-liveness-http
test-liveness-http:
	@echo "Testing HTTP liveness probe..."
	@kubectl apply -f $(MANIFEST_DIR)/01-liveness-http.yaml -n $(NAMESPACE)
	@kubectl wait --for=condition=available --timeout=60s deployment/liveness-http-test -n $(NAMESPACE)

.PHONY: test-liveness-tcp
test-liveness-tcp:
	@echo "Testing TCP liveness probe..."
	@kubectl apply -f $(MANIFEST_DIR)/02-liveness-tcp.yaml -n $(NAMESPACE)
	@kubectl wait --for=condition=available --timeout=60s deployment/liveness-tcp-test -n $(NAMESPACE)

.PHONY: test-liveness-exec
test-liveness-exec:
	@echo "Testing Exec liveness probe..."
	@kubectl apply -f $(MANIFEST_DIR)/03-liveness-exec.yaml -n $(NAMESPACE)
	@echo "Waiting for container restart (this will take ~40 seconds)..."
	@sleep 40
	@kubectl get pod -l app=liveness-exec-test -n $(NAMESPACE)

.PHONY: permissions
permissions:
	@echo "Setting execute permissions on scripts..."
	@chmod +x $(SCRIPT_DIR)/*.sh
	@echo "Permissions set successfully"