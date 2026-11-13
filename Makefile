# depwatch-action. `make check` is what CI runs.

.PHONY: help test lint check

help: ## List the targets
	@grep -E '^[a-z-]+:.*## ' $(MAKEFILE_LIST) | awk -F':.*## ' '{printf "  %-8s %s\n", $$1, $$2}'

test: ## The installer tests
	bash tests/install_test.sh

lint: ## shellcheck (needs shellcheck installed)
	shellcheck install.sh run.sh tests/install_test.sh

check: test lint ## Everything CI runs
